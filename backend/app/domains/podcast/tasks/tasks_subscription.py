"""Procrastinate tasks for subscription sync flows."""

from __future__ import annotations

from typing import Any

from app.core.jobs import exponential_retry, procrastinate_app
from app.domains.podcast.tasks.runtime import worker_session
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)


@procrastinate_app.periodic(cron="0 * * * *", periodic_id="refresh-podcast-feeds")
@procrastinate_app.task(
    name="podcast.subscription.refresh_all_feeds",
    retry=exponential_retry(max_attempts=4),
)
async def refresh_all_podcast_feeds(timestamp: int) -> dict[str, Any]:
    """Refresh all active podcast-rss subscriptions due by user schedule (hourly, UTC)."""
    async with worker_session() as session:
        return await PodcastTaskOrchestrationService(
            session,
        ).refresh_all_podcast_feeds()
