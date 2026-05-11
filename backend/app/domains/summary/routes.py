import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.domains.podcast.models import Episode, ProcessingStatus
from app.domains.podcast.repository import EpisodeRepository
from app.domains.podcast.schemas import SyncResponse
from app.domains.settings.repository import SettingsRepository
from app.domains.summary.repository import SummaryRepository
from app.domains.summary.schemas import (
    BatchSummarizeRequest,
    FeedbackRequest,
    SummaryDetail,
    SummaryResponse,
)
from app.domains.summary.service import SummaryService

router = APIRouter(tags=["summary"])
logger = logging.getLogger(__name__)


@router.post(
    "/episodes/{episode_id}/summarize",
    response_model=SyncResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def summarize_episode(
    episode_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> SyncResponse:
    """Trigger summarization for an episode."""
    # Pre-check: verify an active AI provider is configured
    from app.domains.settings.repository import SettingsRepository

    settings_repo = SettingsRepository(db)
    active_provider = await settings_repo.get_active_provider()
    if active_provider is None:
        raise HTTPException(
            status_code=400,
            detail="No active AI provider configured. Please configure one in Settings.",
        )

    # Verify episode exists
    episode_repo = EpisodeRepository(db)
    episode = await episode_repo.get(episode_id)
    if episode is None:
        raise HTTPException(status_code=404, detail="Episode not found")

    # Check transcript exists
    if episode.transcript_status != ProcessingStatus.COMPLETED:
        raise HTTPException(
            status_code=400,
            detail="Episode must have a completed transcript before summarization",
        )

    # Check if already processing
    if episode.summary_status == ProcessingStatus.PROCESSING:
        raise HTTPException(status_code=409, detail="Summarization already in progress")

    settings_repo = SettingsRepository(db)
    provider = await settings_repo.get_active_provider()
    if provider is None:
        raise HTTPException(status_code=400, detail="No active AI provider configured")
    model = await settings_repo.get_default_model(provider.id)
    if model is None:
        raise HTTPException(status_code=400, detail="No AI model configured for active provider")

    summary_repo = SummaryRepository(db)
    summary = await summary_repo.get_or_create(episode_id)
    await summary_repo.update(
        summary.id,
        {
            "status": ProcessingStatus.PROCESSING,
            "error_message": None,
        },
    )
    await episode_repo.update_status(episode_id, summary_status=ProcessingStatus.PROCESSING)

    from app.core.celery_app import celery_app

    task = celery_app.send_task(
        "app.domains.summary.tasks.summarize_episode_task",
        args=[str(episode_id)],
    )
    logger.info(f"Triggered summarization task for episode {episode_id}: {task.id}")

    return SyncResponse(
        message="Summarization triggered",
        task_id=task.id,
    )


@router.get("/episodes/{episode_id}/summary", response_model=SummaryDetail)
async def get_summary(
    episode_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> SummaryDetail:
    """Get summary for an episode."""
    service = SummaryService(db)
    summary = await service.get_summary(episode_id)
    if summary is None:
        raise HTTPException(status_code=404, detail="Summary not found")
    return SummaryDetail.model_validate(summary)


@router.post("/episodes/batch/summarize", response_model=SyncResponse)
async def batch_summarize(
    request: BatchSummarizeRequest,
    db: AsyncSession = Depends(get_db),
) -> SyncResponse:
    """Batch summarize episodes by IDs or filter status."""
    # Pre-check: verify provider configured
    from app.domains.settings.repository import SettingsRepository

    settings_repo = SettingsRepository(db)
    active_provider = await settings_repo.get_active_provider()
    if active_provider is None:
        raise HTTPException(
            status_code=400,
            detail="No active AI provider configured. Please configure one in Settings.",
        )

    if request.episode_ids:
        episode_ids = [str(eid) for eid in request.episode_ids]
    else:
        status = request.filter_status or ProcessingStatus.PENDING
        result = await db.execute(
            select(Episode.id).where(
                Episode.summary_status == status,
                Episode.transcript_status == ProcessingStatus.COMPLETED,
            ).limit(100)
        )
        episode_ids = [str(row[0]) for row in result.all()]

    if not episode_ids:
        return SyncResponse(message="No episodes to summarize", task_id=None)

    from app.core.celery_app import celery_app

    dispatched = 0
    for eid in episode_ids:
        celery_app.send_task(
            "app.domains.summary.tasks.summarize_episode_task",
            args=[eid],
        )
        dispatched += 1

    return SyncResponse(
        message=f"Dispatched {dispatched} summarization tasks",
        task_id=None,
    )


@router.post("/summaries/{summary_id}/feedback", response_model=SummaryResponse)
async def submit_summary_feedback(
    summary_id: UUID,
    data: FeedbackRequest,
    db: AsyncSession = Depends(get_db),
) -> SummaryResponse:
    """Submit feedback for a summary."""
    repo = SummaryRepository(db)
    summary = await repo.get(summary_id)
    if summary is None:
        raise HTTPException(status_code=404, detail="Summary not found")

    summary = await repo.update(summary_id, {
        "rating": data.rating,
        "feedback": data.feedback,
    })
    await db.commit()
    return SummaryResponse.model_validate(summary)
