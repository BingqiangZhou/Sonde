"""Procrastinate tasks for summary generation flows."""

from __future__ import annotations

from typing import Any

from app.core.jobs import exponential_retry, procrastinate_app
from app.domains.podcast.services.summary_service import SummaryWorkflowService
from app.domains.podcast.tasks.runtime import worker_session


@procrastinate_app.periodic(
    cron="*/30 * * * *",
    periodic_id="generate-pending-summaries",
)
@procrastinate_app.task(
    name="podcast.summary.generate_pending",
    retry=exponential_retry(max_attempts=4),
)
async def generate_pending_summaries(timestamp: int) -> dict[str, Any]:
    """Generate summaries for pending episodes (every 30 minutes, UTC)."""
    async with worker_session() as session:
        workflow = SummaryWorkflowService(session)
        return await workflow.generate_pending_summaries_run()


@procrastinate_app.task(
    name="podcast.summary.generate_episode",
    retry=exponential_retry(max_attempts=4),
)
async def generate_episode_summary(
    episode_id: int,
    summary_model: str | None = None,
    custom_prompt: str | None = None,
) -> dict[str, Any]:
    """Generate an AI summary for one episode."""
    async with worker_session() as session:
        workflow = SummaryWorkflowService(session)
        return await workflow.execute_episode_summary_generation(
            episode_id,
            summary_model=summary_model,
            custom_prompt=custom_prompt,
        )
