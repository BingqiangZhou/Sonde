"""Procrastinate tasks for podcast daily report generation."""

from __future__ import annotations

from datetime import date
from typing import Any

from app.core.jobs import exponential_retry, procrastinate_app
from app.domains.podcast.tasks.runtime import worker_session
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)


@procrastinate_app.periodic(
    cron="30 19 * * *",
    periodic_id="generate-daily-podcast-reports",
)
@procrastinate_app.task(
    name="podcast.report.generate_daily",
    retry=exponential_retry(max_attempts=4),
)
async def generate_daily_podcast_reports(
    timestamp: int,
    report_date: str | None = None,
) -> dict[str, Any]:
    """Generate one daily report snapshot per user (daily 19:30 UTC)."""
    target_date = date.fromisoformat(report_date) if report_date else None
    async with worker_session() as session:
        return await PodcastTaskOrchestrationService(session).generate_daily_reports(
            target_date=target_date,
        )
