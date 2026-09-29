"""Procrastinate tasks for transcription flows."""

from __future__ import annotations

from typing import Any

from app.core.jobs import exponential_retry, procrastinate_app
from app.domains.podcast.tasks.runtime import worker_session
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)


@procrastinate_app.task(
    name="podcast.transcription.process_audio",
    retry=exponential_retry(max_attempts=4),
)
async def process_audio_transcription(
    task_id: int,
    config_db_id: int | None = None,
) -> dict[str, Any]:
    """Execute transcription with lock + state updates."""
    async with worker_session() as session:
        return await PodcastTaskOrchestrationService(
            session,
        ).process_audio_transcription_task(
            task_id=task_id,
            config_db_id=config_db_id,
        )


@procrastinate_app.task(
    name="podcast.transcription.process_episode",
    retry=exponential_retry(max_attempts=4),
)
async def process_podcast_episode_with_transcription(
    episode_id: int,
    user_id: int,
) -> dict[str, Any]:
    """Dispatch the transcription pipeline and return immediately."""
    async with worker_session() as session:
        return await PodcastTaskOrchestrationService(
            session,
        ).trigger_episode_transcription_pipeline(
            episode_id=episode_id,
            user_id=user_id,
        )


@procrastinate_app.task(
    name="podcast.transcription.process_pending",
    retry=exponential_retry(max_attempts=4),
)
async def process_pending_transcriptions() -> dict[str, Any]:
    """Dispatch backlog transcription tasks (dormant: no schedule, no caller)."""
    async with worker_session() as session:
        return await PodcastTaskOrchestrationService(
            session,
        ).process_pending_transcriptions()
