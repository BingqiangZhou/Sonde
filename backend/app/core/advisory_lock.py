"""Postgres advisory-lock helpers (replace the former Redis locks)."""

from __future__ import annotations

import logging
import zlib
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine

from app.core.database import get_engine


logger = logging.getLogger(__name__)


def string_lock_key(name: str) -> int:
    """Map a lock name to a stable positive bigint for pg_advisory_lock.

    ``zlib.crc32`` is stable across processes and platforms, unlike
    ``hash()`` (PYTHONHASHSEED-randomized). 31 bits keep the key inside a
    comfortable bigint range with no collision concerns at this scale.
    """
    return zlib.crc32(name.encode("utf-8")) & 0x7FFFFFFF


async def try_advisory_lock(
    conn,
    key: int,
) -> bool:
    """Try to take a session-scoped advisory lock on an open connection."""
    acquired = (
        await conn.execute(text("SELECT pg_try_advisory_lock(:key)"), {"key": key})
    ).scalar()
    return bool(acquired)


async def advisory_unlock(conn, key: int) -> None:
    """Release a session-scoped advisory lock on an open connection."""
    await conn.execute(text("SELECT pg_advisory_unlock(:key)"), {"key": key})


async def advisory_lock_exists(engine: AsyncEngine, key: int) -> bool:
    """Check whether any session in the cluster holds this advisory lock."""
    async with engine.connect() as conn:
        stmt = text(
            "SELECT EXISTS(SELECT 1 FROM pg_locks "
            "WHERE locktype = 'advisory' AND objsubid = 1 AND objid = :key)"
        )
        return bool((await conn.execute(stmt, {"key": key})).scalar())


@asynccontextmanager
async def advisory_lock(
    lock_name: str,
    *,
    engine: AsyncEngine | None = None,
) -> AsyncIterator[bool]:
    """Hold a Postgres advisory lock for the duration of the block.

    The lock lives on a dedicated connection: it is released explicitly on
    block exit and automatically when the owning process (or its DB
    connection) dies — crash-safe semantics that replace fixed-TTL Redis
    locks. Yields ``False`` when another process already holds the lock.
    """
    target_engine = engine or get_engine()
    key = string_lock_key(lock_name)
    async with target_engine.connect() as conn:
        acquired = await try_advisory_lock(conn, key)
        if not acquired:
            logger.debug("Advisory lock %r is held elsewhere", lock_name)
        try:
            yield acquired
        finally:
            if acquired:
                try:
                    await advisory_unlock(conn, key)
                except Exception:
                    logger.warning(
                        "Failed to release advisory lock %r; it will be freed "
                        "when the connection closes",
                        lock_name,
                        exc_info=True,
                    )


__all__ = [
    "advisory_lock",
    "advisory_lock_exists",
    "advisory_unlock",
    "string_lock_key",
    "try_advisory_lock",
]
