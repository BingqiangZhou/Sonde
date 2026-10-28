"""Auth/user 测试夹具：内存 SQLite + ASGI 客户端（Phase B）。"""

from __future__ import annotations

from collections.abc import AsyncGenerator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

import app.domains.podcast.models  # noqa: F401
import app.domains.user.models  # noqa: F401
from app.core.auth import get_db_session_dependency

# 确保所有模型注册到 Base.metadata（含 podcast/user）
from app.core.database import Base  # noqa: F401


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as session:
        yield session
    await engine.dispose()


@pytest.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """命中真实路由栈的 ASGI 客户端（DB 会话替换为内存库）。"""
    from app.main import app

    async def _override():
        yield db_session

    app.dependency_overrides[get_db_session_dependency] = _override
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    app.dependency_overrides.pop(get_db_session_dependency, None)
