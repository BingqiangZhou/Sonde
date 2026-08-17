"""Shared fixtures for auth domain tests: real in-memory SQLite via HTTP."""

from collections.abc import AsyncGenerator

import pytest
import pytest_asyncio
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.auth import get_db_session_dependency
from app.core.database import Base, register_orm_models
from app.core.rate_limit import limiter
from app.main import app


TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

test_engine = create_async_engine(TEST_DATABASE_URL, echo=False, future=True)
TestSessionLocal = async_sessionmaker(
    test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


@pytest_asyncio.fixture(autouse=True)
async def auth_db() -> AsyncGenerator[None, None]:
    """Route DB traffic to a fresh in-memory schema; reset rate limits."""
    register_orm_models()
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async def override_session() -> AsyncGenerator[AsyncSession, None]:
        async with TestSessionLocal() as session:
            yield session

    app.dependency_overrides[get_db_session_dependency] = override_session
    limiter.reset()
    try:
        yield
    finally:
        app.dependency_overrides.pop(get_db_session_dependency, None)
        limiter.reset()
        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)
