"""Procrastinate tasks for maintenance, housekeeping, and OPML import."""

from __future__ import annotations

from typing import Any

from app.core.jobs import exponential_retry, procrastinate_app
from app.domains.podcast.tasks.runtime import worker_session
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)


@procrastinate_app.task(
    name="podcast.maintenance.cleanup_old_playback_states",
    retry=exponential_retry(max_attempts=3),
)
async def cleanup_old_playback_states() -> dict[str, Any]:
    """Delete playback states older than 90 days (dormant: no schedule)."""
    async with worker_session() as session:
        return await PodcastTaskOrchestrationService(
            session,
        ).cleanup_old_playback_states()


@procrastinate_app.task(
    name="podcast.maintenance.cleanup_old_transcription_temp_files",
    retry=exponential_retry(max_attempts=3),
)
async def cleanup_old_transcription_temp_files(days: int = 7) -> dict[str, Any]:
    """Clean stale transcription temporary files (dormant: no schedule)."""
    async with worker_session() as session:
        return await PodcastTaskOrchestrationService(
            session,
        ).cleanup_old_transcription_temp_files(days=days)


@procrastinate_app.periodic(cron="0 4 * * *", periodic_id="auto-cleanup-cache")
@procrastinate_app.task(name="podcast.maintenance.auto_cleanup_cache")
async def auto_cleanup_cache_files(timestamp: int) -> dict[str, Any]:
    """Execute cache cleanup when enabled by admin settings (daily 04:00 UTC)."""
    async with worker_session() as session:
        return await PodcastTaskOrchestrationService(session).auto_cleanup_cache_files()


@procrastinate_app.task(
    name="podcast.maintenance.process_opml_subscription_episodes",
    retry=exponential_retry(max_attempts=4),
)
async def process_opml_subscription_episodes(
    subscription_id: int,
    user_id: int,
    source_url: str,
) -> dict[str, Any]:
    """Parse and upsert episodes for one OPML subscription in background."""
    async with worker_session() as session:
        return await PodcastTaskOrchestrationService(
            session,
        ).process_opml_subscription_episodes(
            subscription_id=subscription_id,
            user_id=user_id,
            source_url=source_url,
        )
