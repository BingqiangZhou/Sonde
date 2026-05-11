import logging
from uuid import UUID

from app.core.celery_app import celery_app
from app.core.database import async_session_factory

logger = logging.getLogger(__name__)


@celery_app.task(
    name="app.domains.summary.tasks.summarize_episode_task",
    bind=True,
    max_retries=3,
    default_retry_delay=120,
)
def summarize_episode_task(self, episode_id: str) -> dict:
    """Celery task: summarize an episode.

    Args:
        episode_id: The episode UUID as string.

    Returns:
        Dict with summarization result status.
    """
    import asyncio

    from app.domains.summary.service import SummaryService

    async def _run() -> dict:
        async with async_session_factory() as session:
            try:
                service = SummaryService(session)
                summary = await service.summarize_episode(UUID(episode_id))
                await session.commit()
                return {
                    "episode_id": episode_id,
                    "summary_id": str(summary.id),
                    "status": summary.status.value,
                }
            except Exception:
                await session.rollback()
                raise

    async def _mark_failed(error_message: str) -> None:
        from app.domains.podcast.models import ProcessingStatus
        from app.domains.podcast.repository import EpisodeRepository
        from app.domains.summary.repository import SummaryRepository

        async with async_session_factory() as session:
            summary_repo = SummaryRepository(session)
            episode_repo = EpisodeRepository(session)
            await summary_repo.mark_failed(UUID(episode_id), error_message)
            await episode_repo.update_status(
                UUID(episode_id), summary_status=ProcessingStatus.FAILED
            )
            await session.commit()

    try:
        return asyncio.run(_run())
    except Exception as exc:
        logger.error(f"Summarization task failed for episode {episode_id}: {exc}")
        asyncio.run(_mark_failed(str(exc)))
        raise self.retry(exc=exc, countdown=120)
