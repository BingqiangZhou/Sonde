"""Shared runtime helpers for podcast queue tasks."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import (
    get_async_session_factory,
    register_orm_models,
)


def ensure_orm_models_registered() -> None:
    """Register ORM models when the task runtime first needs them."""
    register_orm_models()


@asynccontextmanager
async def worker_session() -> AsyncIterator[AsyncSession]:
    """Create an isolated worker DB session."""
    ensure_orm_models_registered()
    session_factory = get_async_session_factory()
    async with session_factory() as session:
        yield session
