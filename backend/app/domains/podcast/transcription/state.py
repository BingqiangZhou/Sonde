"""Transcription State Manager - Postgres advisory locking.

Episode locks prevent duplicate processing of the same episode: each lock is
a session-scoped advisory lock held on a dedicated connection, released on
completion and automatically freed when the owning process (or its DB
connection) dies — crash-safe semantics that replace the former Redis TTL
locks. Dispatch dedup is enforced by the task-status check below plus the
queueing_lock taken at enqueue time.

Progress and status are read from the database (the single source of
truth); no mirror state is maintained for them.
"""

import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncEngine

from app.core.advisory_lock import (
    advisory_lock_exists,
    string_lock_key,
    try_advisory_lock,
)
from app.core.database import get_engine


logger = logging.getLogger(__name__)

# Returned by is_episode_locked when the lock exists but is owned by another
# process (advisory locks carry no owner payload). Never matches a real id,
# so callers treat the episode as locked by another task.
UNKNOWN_OWNER_TASK_ID = -1


class TranscriptionStateManager:
    """Postgres advisory-lock manager for transcription episode locks."""

    def __init__(self, *, engine: AsyncEngine | None = None):
        self.engine = engine or get_engine()
        # episode_id -> (owner task_id, dedicated connection holding the lock)
        self._held: dict[int, tuple[int, AsyncConnection]] = {}

    @staticmethod
    def _lock_key(episode_id: int) -> int:
        return string_lock_key(f"transcription:episode:{episode_id}")

    # === Lock Operations ===

    async def acquire_task_lock(
        self,
        episode_id: int,
        task_id: int,
        expire_seconds: int = 3600,
    ) -> bool:
        """Acquire a lock for processing an episode.

        The lock is held on a dedicated connection until released (or until
        the process dies); ``expire_seconds`` is accepted for signature
        compatibility and ignored — crash-safety replaces fixed TTLs.

        Args:
            episode_id: Episode to lock
            task_id: Task ID that owns the lock
            expire_seconds: Unused (kept for call-site compatibility)

        Returns:
            True if lock acquired, False if already locked

        """
        held = self._held.get(episode_id)
        if held is not None:
            if held[0] == task_id:
                logger.info(
                    "[LOCK] Task %s already owns lock for episode %s",
                    task_id,
                    episode_id,
                )
                return True
            logger.warning(
                "[LOCK] Episode %s already locked [owned_by_task=%s]",
                episode_id,
                held[0],
            )
            return False

        key = self._lock_key(episode_id)
        conn: AsyncConnection | None = None
        try:
            conn = await self.engine.connect()
            acquired = await try_advisory_lock(conn, key)
            if acquired:
                self._held[episode_id] = (task_id, conn)
                logger.info(
                    "[LOCK] Acquired lock for episode %s, task %s",
                    episode_id,
                    task_id,
                )
                return True
            await conn.close()
            logger.warning(
                "[LOCK] Episode %s already locked by another process",
                episode_id,
            )
            return False
        except Exception as e:
            logger.error("Failed to acquire lock for episode %s: %s", episode_id, e)
            if conn is not None:
                try:
                    await conn.close()
                except Exception:
                    logger.warning(
                        "Failed closing lock connection for episode %s",
                        episode_id,
                        exc_info=True,
                    )
            return False

    async def release_task_lock(self, episode_id: int, task_id: int) -> bool:
        """Release a task lock.

        Args:
            episode_id: Episode to unlock
            task_id: Task ID that owns the lock

        Returns:
            True if the lock was released (or was not held), False if it is
            owned by another process/task.

        """
        try:
            held = self._held.get(episode_id)
            if held is None:
                # Not held in this process: advisory locks cannot be
                # released cross-process by design. Report foreign holders.
                if await advisory_lock_exists(self.engine, self._lock_key(episode_id)):
                    logger.warning(
                        "[LOCK] Episode %s lock is held by another process; "
                        "it frees when that process exits",
                        episode_id,
                    )
                    return False
                return True

            owner_task_id, conn = held
            if owner_task_id != task_id:
                logger.warning(
                    "Cannot release lock for episode %s: owned by task %s, not %s",
                    episode_id,
                    owner_task_id,
                    task_id,
                )
                return False

            from sqlalchemy import text

            await conn.execute(
                text("SELECT pg_advisory_unlock(:key)"),
                {"key": self._lock_key(episode_id)},
            )
            await conn.close()
            del self._held[episode_id]
            logger.info(
                "[LOCK] Released lock for episode %s, task %s", episode_id, task_id
            )
            return True
        except Exception as e:
            logger.error("Failed to release lock for episode %s: %s", episode_id, e)
            return False

    async def is_episode_locked(self, episode_id: int) -> int | None:
        """Check if an episode is locked and return the owning task ID.

        Args:
            episode_id: Episode to check

        Returns:
            Task ID if locked in this process, UNKNOWN_OWNER_TASK_ID if the
            lock exists in another process, None if not locked.

        """
        held = self._held.get(episode_id)
        if held is not None:
            return held[0]
        try:
            if await advisory_lock_exists(self.engine, self._lock_key(episode_id)):
                return UNKNOWN_OWNER_TASK_ID
            return None
        except Exception:
            logger.exception("Failed to check lock for episode %s", episode_id)
            return None

    # === Cleanup ===

    async def clear_task_state(self, task_id: int, episode_id: int) -> None:
        """Clear lock state for a completed task."""
        try:
            await self.release_task_lock(episode_id, task_id)
            logger.info(
                "[STATE] Cleared state for task %s, episode %s", task_id, episode_id
            )
        except Exception as e:
            logger.error("Failed to clear state for task %s: %s", task_id, e)

    async def fail_task_state(
        self,
        task_id: int,
        episode_id: int,
        error_message: str,
    ) -> None:
        """Release locks for a failed task."""
        await self.release_task_lock(episode_id, task_id)
        logger.error("[STATE] Task %s failed: %s", task_id, error_message)


# Singleton instance
_state_manager = None


async def get_transcription_state_manager() -> TranscriptionStateManager:
    """Get singleton state manager instance"""
    global _state_manager
    if _state_manager is None:
        _state_manager = TranscriptionStateManager()
    return _state_manager


# ── Dispatch guard (single source of truth for claim semantics) ────────


async def claim_task_dispatch(
    db,
    task_id: int,
) -> bool:
    """Claim the dispatch right for a task (replaces the Redis guard key).

    Queue-time dedup is the queueing_lock set by the enqueue helper; this
    worker-side check guards execution: returns True when the task may
    execute, False when it is already finished, and raises when a live
    duplicate dispatch is detected. Concurrent execution is finally fenced
    by the episode advisory lock taken right after this claim.
    """
    from app.domains.podcast.models import TranscriptionTask
    from app.domains.podcast.utils.status_helpers import status_value

    status_stmt = select(TranscriptionTask.status).where(
        TranscriptionTask.id == task_id
    )
    status_result = await db.execute(status_stmt)
    task_status_value = status_value(status_result.scalar_one_or_none())
    if task_status_value in {"completed", "failed", "cancelled"}:
        return False
    if task_status_value == "in_progress":
        raise RuntimeError(
            f"Task {task_id} dispatch detected while status=in_progress",
        )
    return True
