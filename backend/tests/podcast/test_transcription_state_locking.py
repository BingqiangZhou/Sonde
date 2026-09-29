from __future__ import annotations

from types import SimpleNamespace
from typing import Any

import pytest

from app.domains.podcast.transcription.state import (
    UNKNOWN_OWNER_TASK_ID,
    TranscriptionStateManager,
)


class _FakeConn:
    """Emulates an AsyncConnection: execute() results with .scalar()."""

    def __init__(self, scalars: list[Any] | None = None):
        self._scalars = list(scalars or [])
        self.executed: list[str] = []
        self.closed = False

    async def execute(self, stmt, params=None):
        self.executed.append(str(stmt))
        value = self._scalars.pop(0) if self._scalars else True
        return SimpleNamespace(scalar=lambda: value)

    async def close(self):
        self.closed = True

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_exc):
        return None


class _FakeConnectionHandle:
    """Awaitable + async-context-manager wrapper, like AsyncEngine.connect()."""

    def __init__(self, conn: _FakeConn):
        self._conn = conn

    def __await__(self):
        async def _coro():
            return self._conn

        return _coro().__await__()

    async def __aenter__(self):
        return self._conn

    async def __aexit__(self, *_exc):
        return None


class _FakeEngine:
    def __init__(self):
        self._queue: list[_FakeConn] = []
        self.connections: list[_FakeConn] = []

    def queue(self, conn: _FakeConn) -> None:
        self._queue.append(conn)

    def connect(self) -> _FakeConnectionHandle:
        conn = self._queue.pop(0) if self._queue else _FakeConn()
        self.connections.append(conn)
        return _FakeConnectionHandle(conn)


def _build_state_manager(
    engine: _FakeEngine | None = None,
) -> tuple[TranscriptionStateManager, _FakeEngine]:
    engine = engine or _FakeEngine()
    return TranscriptionStateManager(engine=engine), engine


@pytest.mark.asyncio
async def test_acquire_reentrant_and_local_owner_tracking() -> None:
    engine = _FakeEngine()
    engine.queue(_FakeConn([True]))  # pg_try_advisory_lock succeeds
    manager = TranscriptionStateManager(engine=engine)

    assert await manager.acquire_task_lock(60329, 42) is True
    # Re-entrant acquire by the same task needs no extra connection.
    assert await manager.acquire_task_lock(60329, 42) is True
    assert await manager.is_episode_locked(60329) == 42
    # Another task in the same process is refused.
    assert await manager.acquire_task_lock(60329, 99) is False
    assert len(engine.connections) == 1


@pytest.mark.asyncio
async def test_acquire_fails_when_foreign_process_holds_lock() -> None:
    engine = _FakeEngine()
    engine.queue(_FakeConn([False]))  # pg_try_advisory_lock fails
    manager = TranscriptionStateManager(engine=engine)

    assert await manager.acquire_task_lock(60329, 88) is False
    # The dedicated connection of the failed acquire is closed.
    assert engine.connections[0].closed is True


@pytest.mark.asyncio
async def test_is_episode_locked_reports_unknown_owner_for_foreign_lock() -> None:
    manager, engine = _build_state_manager()
    engine.queue(_FakeConn([True]))  # pg_locks: lock exists

    assert await manager.is_episode_locked(60329) == UNKNOWN_OWNER_TASK_ID


@pytest.mark.asyncio
async def test_is_episode_locked_returns_none_when_free() -> None:
    manager, engine = _build_state_manager()
    engine.queue(_FakeConn([False]))  # pg_locks: no lock

    assert await manager.is_episode_locked(60329) is None


@pytest.mark.asyncio
async def test_release_rejects_foreign_owner() -> None:
    engine = _FakeEngine()
    engine.queue(_FakeConn([True]))
    manager = TranscriptionStateManager(engine=engine)
    await manager.acquire_task_lock(60329, 11)

    assert await manager.release_task_lock(60329, 99) is False
    assert await manager.is_episode_locked(60329) == 11


@pytest.mark.asyncio
async def test_release_unlocks_and_closes_connection() -> None:
    engine = _FakeEngine()
    engine.queue(_FakeConn([True]))
    manager = TranscriptionStateManager(engine=engine)
    await manager.acquire_task_lock(60329, 11)

    assert await manager.release_task_lock(60329, 11) is True
    assert engine.connections[0].closed is True

    engine.queue(_FakeConn([False]))
    assert await manager.is_episode_locked(60329) is None


@pytest.mark.asyncio
async def test_release_without_local_holder_is_idempotent_when_free() -> None:
    manager, engine = _build_state_manager()
    engine.queue(_FakeConn([False]))  # advisory_lock_exists → False

    assert await manager.release_task_lock(60329, 1) is True


@pytest.mark.asyncio
async def test_release_without_local_holder_refuses_foreign_lock() -> None:
    manager, engine = _build_state_manager()
    engine.queue(_FakeConn([True]))  # advisory_lock_exists → True

    assert await manager.release_task_lock(60329, 1) is False
