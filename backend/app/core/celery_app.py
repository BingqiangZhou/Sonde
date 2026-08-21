"""Central Celery application entrypoint."""

from __future__ import annotations

import asyncio
import logging
from typing import Any

from celery import Celery
from celery.schedules import crontab
from celery.signals import worker_process_init, worker_process_shutdown

from app.core.config import get_settings


_logger = logging.getLogger(__name__)


_celery_app: Celery | None = None


def _build_beat_schedule() -> dict[str, Any]:
    return {
        "refresh-podcast-feeds": {
            "task": "app.domains.podcast.tasks.tasks_subscription.refresh_all_podcast_feeds",
            "schedule": crontab(minute=0),
            "options": {"queue": "default"},
        },
        "generate-pending-summaries": {
            "task": "app.domains.podcast.tasks.tasks_summary.generate_pending_summaries",
            "schedule": 1800.0,
            "options": {"queue": "default"},
        },
        "auto-cleanup-cache": {
            "task": "app.domains.podcast.tasks.tasks_maintenance.auto_cleanup_cache_files",
            "schedule": crontab(hour=4, minute=0),
            "options": {"queue": "default"},
        },
        "generate-daily-podcast-reports": {
            "task": "app.domains.podcast.tasks.tasks_daily_report.generate_daily_podcast_reports",
            "schedule": crontab(hour=19, minute=30),
            "options": {"queue": "default"},
        },
    }


def create_celery_app() -> Celery:
    """Create and configure the Celery application lazily."""
    global _celery_app
    if _celery_app is not None:
        return _celery_app

    settings = get_settings()
    celery = Celery(
        "personal_ai_tasks",
        broker=settings.CELERY_BROKER_URL,
        backend=settings.CELERY_RESULT_BACKEND,
    )
    celery.conf.update(
        task_serializer="json",
        accept_content=["json"],
        result_serializer="json",
        timezone="UTC",
        enable_utc=True,
        task_track_started=True,
        task_time_limit=30 * 60,
        task_soft_time_limit=25 * 60,
        # Tasks are idempotent (redis dispatch claims + upserts): losing a
        # worker mid-task must requeue instead of silently dropping the job.
        task_acks_late=True,
        task_reject_on_worker_lost=True,
        worker_prefetch_multiplier=settings.CELERY_WORKER_PREFETCH_MULTIPLIER,
        worker_max_tasks_per_child=settings.CELERY_WORKER_MAX_TASKS_PER_CHILD,
        beat_schedule=_build_beat_schedule(),
    )

    _celery_app = celery

    # Ensure task modules are imported so Celery registers them.
    import app.domains.podcast.tasks  # noqa: F401

    return celery


# ---------------------------------------------------------------------------
# Worker lifecycle hooks
# ---------------------------------------------------------------------------


async def _reset_stale_transcription_tasks_on_boot() -> None:
    """Reset stale transcription tasks on a throwaway event loop.

    The shared DB engine is loop-bound; this coroutine runs on its own loop
    inside ``worker_process_init`` and must fully dispose that engine before
    returning so the persistent worker loop recreates it lazily.
    """
    from app.core.database import close_db, get_async_session_factory
    from app.core.redis import close_shared_redis, get_shared_redis
    from app.domains.podcast.services.transcription_service import (
        TranscriptionWorkflowService,
    )

    redis = get_shared_redis()
    acquired = await redis.acquire_lock(
        "startup:reset-stale-transcription-tasks", expire=300
    )
    if not acquired:
        _logger.info("Skipped worker-boot stale reset; another holder owns the lock")
        return
    try:
        factory = get_async_session_factory()
        async with factory() as session:
            async with asyncio.timeout(120):
                await TranscriptionWorkflowService(session).reset_stale_tasks()
        _logger.info("Reset stale transcription tasks during worker boot")
    finally:
        await redis.release_lock("startup:reset-stale-transcription-tasks")
        await close_db()
        await close_shared_redis()


try:

    @worker_process_init.connect
    def _on_worker_process_init(**kwargs):  # type: ignore[misc]
        """Mark transcription tasks orphaned by a crashed worker as failed.

        The API-process lifespan covers deploys; this hook covers worker-only
        restarts, so stale in-flight tasks don't wait for the next API boot.
        """
        try:
            asyncio.run(_reset_stale_transcription_tasks_on_boot())
        except Exception:
            _logger.warning("Worker-boot stale task reset failed", exc_info=True)

    @worker_process_shutdown.connect
    def _on_worker_process_shutdown(**kwargs):  # type: ignore[misc]
        """Dispose DB engines and close the worker event loop on shutdown."""
        try:
            from app.domains.podcast.tasks.runtime import _worker_loop

            if _worker_loop is not None and not _worker_loop.is_closed():
                from app.core.database import close_db

                _worker_loop.run_until_complete(close_db())
                _worker_loop.close()
        except Exception:
            _logger.warning(
                "Failed to dispose worker DB engines during shutdown", exc_info=True
            )
except ImportError:
    pass


class _LazyCeleryApp:
    """Proxy that resolves the Celery application on first use."""

    def __getattr__(self, name: str) -> Any:
        return getattr(create_celery_app(), name)

    def __repr__(self) -> str:
        return repr(create_celery_app())


celery_app = _LazyCeleryApp()


__all__ = ["celery_app", "create_celery_app"]
