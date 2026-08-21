"""Integration fixtures: real postgres + redis from the docker-compose stack.

These tests create an isolated ``sonde_test_*`` database (dropped afterwards)
and use redis DB 15 (flushed), so they never touch dev data. The whole module
skips automatically when the local stack is not reachable — run the suite
with ``docker compose up -d`` first when you want them included.
"""

import asyncio
import threading
import uuid
from collections.abc import AsyncGenerator
from pathlib import Path

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.database import Base, register_orm_models


_DOCKER_ENV = Path(__file__).resolve().parents[3] / "docker" / ".env"


def _load_docker_env() -> dict[str, str]:
    env: dict[str, str] = {}
    if not _DOCKER_ENV.exists():
        return env
    for line in _DOCKER_ENV.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = value.strip().strip(chr(34)).strip(chr(39))
    return env


def _pg_port(env: dict[str, str]) -> int:
    raw = (env.get("DB_PORT") or "").strip() or "127.0.0.1:5432"
    return int(raw.split(":")[-1]) if ":" in raw else int(raw)


def _tcp_reachable(host: str, port: int) -> bool:
    import socket

    try:
        with socket.create_connection((host, port), timeout=1.5):
            return True
    except OSError:
        return False


def _stack_available() -> tuple[bool, str]:
    env = _load_docker_env()
    pg_ok = _tcp_reachable("127.0.0.1", _pg_port(env))
    redis_ok = _tcp_reachable("127.0.0.1", 6379)
    if pg_ok and redis_ok:
        return True, ""
    missing = []
    if not pg_ok:
        missing.append("postgres")
    if not redis_ok:
        missing.append("redis")
    reason = "docker-compose stack not reachable: " + ", ".join(missing)
    return False, reason


STACK_OK, STACK_REASON = _stack_available()

pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(not STACK_OK, reason=STACK_REASON),
]


def _admin_url(env: dict[str, str]) -> str:
    user = env.get("POSTGRES_USER", "admin")
    password = env["POSTGRES_PASSWORD"]
    port = _pg_port(env)
    return f"postgresql+asyncpg://{user}:{password}@127.0.0.1:{port}/postgres"


def _run_in_thread(coro_factory):
    """Run a coroutine on a throwaway loop in a worker thread.

    Database admin (CREATE/DROP DATABASE) runs exactly once per session and
    must not bind connections to any pytest event loop.
    """
    result: dict = {}

    def runner():
        loop = asyncio.new_event_loop()
        try:
            result["value"] = loop.run_until_complete(coro_factory())
        finally:
            loop.close()

    t = threading.Thread(target=runner)
    t.start()
    t.join()
    return result.get("value")


@pytest.fixture(scope="session")
def pg_database():
    """Create an isolated test database on the real postgres server."""
    env = _load_docker_env()
    dbname = f"sonde_test_{uuid.uuid4().hex[:8]}"

    async def _create():
        engine = create_async_engine(_admin_url(env), isolation_level="AUTOCOMMIT")
        async with engine.begin() as conn:
            await conn.execute(text(f'CREATE DATABASE "{dbname}"'))
        await engine.dispose()

    _run_in_thread(_create)
    yield dbname

    async def _drop():
        engine = create_async_engine(_admin_url(env), isolation_level="AUTOCOMMIT")
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                    "WHERE datname = :d AND pid <> pg_backend_pid()"
                ),
                {"d": dbname},
            )
            await conn.execute(text(f'DROP DATABASE "{dbname}"'))
        await engine.dispose()

    _run_in_thread(_drop)


@pytest_asyncio.fixture
async def integration_engine(pg_database: str) -> AsyncGenerator:
    """Per-test engine bound to the test's own event loop."""
    env = _load_docker_env()
    user = env.get("POSTGRES_USER", "admin")
    password = env["POSTGRES_PASSWORD"]
    port = _pg_port(env)
    register_orm_models()
    engine = create_async_engine(
        f"postgresql+asyncpg://{user}:{password}@127.0.0.1:{port}/{pg_database}",
        pool_pre_ping=True,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(integration_engine) -> AsyncGenerator[AsyncSession, None]:
    """Session on the real test database; tables truncated after each test.

    Repositories commit internally, so rollback alone cannot isolate tests.
    """
    factory = async_sessionmaker(
        integration_engine, class_=AsyncSession, expire_on_commit=False
    )
    async with factory() as session:
        yield session

    async with integration_engine.begin() as conn:
        await conn.execute(
            text(
                "TRUNCATE TABLE podcast_episodes, transcription_tasks, "
                "user_subscriptions, subscriptions, users "
                "RESTART IDENTITY CASCADE"
            )
        )


@pytest_asyncio.fixture(autouse=True)
async def real_redis():
    """Point the shared RedisCache at compose redis DB 15 for the process."""
    import app.core.redis as redis_module
    from app.core.config import get_settings

    env = _load_docker_env()
    password = env.get("REDIS_PASSWORD", "")
    auth = f":{password}@" if password else ""
    original_url = get_settings().REDIS_URL

    get_settings().REDIS_URL = f"redis://{auth}127.0.0.1:6379/15"
    redis_module._shared_redis = None

    redis = redis_module.get_shared_redis()
    client = await redis._get_client()
    await client.flushdb()

    yield redis

    await redis_module.close_shared_redis()
    get_settings().REDIS_URL = original_url
