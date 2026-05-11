import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.domains.podcast.models import Episode, ProcessingStatus
from app.domains.podcast.repository import EpisodeRepository
from app.domains.podcast.schemas import SyncResponse
from app.domains.transcription.models import Transcript
from app.domains.transcription.schemas import (
    BatchTranscribeRequest,
    FeedbackRequest,
    TranscriptDetail,
    TranscriptResponse,
)
from app.domains.transcription.repository import TranscriptRepository
from app.domains.transcription.service import TranscriptionService

router = APIRouter(tags=["transcription"])
logger = logging.getLogger(__name__)


@router.post(
    "/episodes/{episode_id}/transcribe",
    response_model=SyncResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def transcribe_episode(
    episode_id: UUID,
    force: bool = Query(False, description="Force re-transcription even if completed"),
    db: AsyncSession = Depends(get_db),
) -> SyncResponse:
    """Queue transcription for an episode."""
    episode_repo = EpisodeRepository(db)
    episode = await episode_repo.get(episode_id)
    if episode is None:
        raise HTTPException(status_code=404, detail="Episode not found")

    if not episode.audio_url:
        raise HTTPException(status_code=400, detail="Episode has no audio URL")

    if episode.transcript_status == ProcessingStatus.PROCESSING:
        raise HTTPException(
            status_code=409, detail="Transcription already in progress"
        )

    transcript_repo = TranscriptRepository(db)
    transcript = await transcript_repo.get_or_create(episode_id)
    await transcript_repo.update(
        transcript.id,
        {
            "status": ProcessingStatus.PROCESSING,
            "error_message": None,
        },
    )
    await episode_repo.update_status(
        episode_id, transcript_status=ProcessingStatus.PROCESSING
    )

    from app.core.celery_app import celery_app

    task = celery_app.send_task(
        "app.domains.transcription.tasks.transcribe_episode_task",
        args=[str(episode_id)],
    )
    logger.info("Queued transcription task for episode %s: %s", episode_id, task.id)
    return SyncResponse(message="Transcription queued", task_id=task.id)


@router.get("/episodes/{episode_id}/transcript", response_model=TranscriptDetail)
async def get_transcript(
    episode_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> TranscriptDetail:
    """Get transcript for an episode."""
    service = TranscriptionService(db)
    transcript = await service.get_transcript(episode_id)
    if transcript is None:
        raise HTTPException(status_code=404, detail="Transcript not found")
    return TranscriptDetail.model_validate(transcript)


@router.post(
    "/episodes/{episode_id}/transcribe/retry",
    response_model=SyncResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def retry_transcription(
    episode_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> SyncResponse:
    """Retry failed transcription for an episode."""
    episode_repo = EpisodeRepository(db)
    episode = await episode_repo.get(episode_id)
    if episode is None:
        raise HTTPException(status_code=404, detail="Episode not found")

    if episode.transcript_status != ProcessingStatus.FAILED:
        raise HTTPException(
            status_code=400,
            detail="Can only retry failed transcriptions",
        )

    transcript_repo = TranscriptRepository(db)
    transcript = await transcript_repo.get_or_create(episode_id)
    await transcript_repo.update(
        transcript.id,
        {
            "status": ProcessingStatus.PROCESSING,
            "error_message": None,
        },
    )
    await episode_repo.update_status(
        episode_id, transcript_status=ProcessingStatus.PROCESSING
    )

    from app.core.celery_app import celery_app

    task = celery_app.send_task(
        "app.domains.transcription.tasks.transcribe_episode_task",
        args=[str(episode_id)],
    )
    logger.info("Queued transcription retry for episode %s: %s", episode_id, task.id)
    return SyncResponse(message="Transcription retry queued", task_id=task.id)


@router.post("/episodes/batch/transcribe", response_model=SyncResponse)
async def batch_transcribe(
    request: BatchTranscribeRequest,
    db: AsyncSession = Depends(get_db),
) -> SyncResponse:
    """Batch transcribe episodes by IDs or filter status."""
    episode_repo = EpisodeRepository(db)

    if request.episode_ids:
        episode_ids = [str(eid) for eid in request.episode_ids]
    else:
        # Query episodes by status
        filter_status = request.filter_status or ProcessingStatus.PENDING
        result = await db.execute(
            select(Episode.id).where(
                Episode.transcript_status == filter_status,
                Episode.audio_url != None,  # noqa: E711
            ).limit(100)
        )
        episode_ids = [str(row[0]) for row in result.all()]

    if not episode_ids:
        return SyncResponse(message="No episodes to transcribe", task_id=None)

    from app.core.celery_app import celery_app

    dispatched = 0
    for eid in episode_ids:
        celery_app.send_task(
            "app.domains.transcription.tasks.transcribe_episode_task",
            args=[eid],
        )
        dispatched += 1

    return SyncResponse(
        message=f"Dispatched {dispatched} transcription tasks",
        task_id=None,
    )


@router.post("/transcripts/{transcript_id}/feedback", response_model=TranscriptResponse)
async def submit_transcript_feedback(
    transcript_id: UUID,
    data: FeedbackRequest,
    db: AsyncSession = Depends(get_db),
) -> TranscriptResponse:
    """Submit feedback for a transcript."""
    repo = TranscriptRepository(db)
    transcript = await repo.get(transcript_id)
    if transcript is None:
        raise HTTPException(status_code=404, detail="Transcript not found")

    transcript = await repo.update(transcript_id, {
        "rating": data.rating,
        "feedback": data.feedback,
    })
    await db.commit()
    return TranscriptResponse.model_validate(transcript)
