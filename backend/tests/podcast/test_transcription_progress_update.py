from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.models import TranscriptionStatus
from app.domains.podcast.transcription import PodcastTranscriptionService


@pytest.mark.asyncio
async def test_cancel_transcription_marks_active_task_cancelled():
    db = AsyncMock()
    task = SimpleNamespace(
        status=TranscriptionStatus.IN_PROGRESS, progress_percentage=42.0
    )
    db.execute.side_effect = [
        SimpleNamespace(scalar_one_or_none=lambda: task),
        SimpleNamespace(rowcount=1),
    ]
    service = PodcastTranscriptionService(db)

    cancelled = await service.cancel_transcription(task_id=123)

    assert cancelled is True
    assert db.execute.await_count == 2
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "status",
    [
        TranscriptionStatus.COMPLETED,
        TranscriptionStatus.FAILED,
        TranscriptionStatus.CANCELLED,
    ],
)
async def test_cancel_transcription_rejects_finished_tasks(status):
    db = AsyncMock()
    task = SimpleNamespace(status=status, progress_percentage=100.0)
    db.execute.side_effect = [SimpleNamespace(scalar_one_or_none=lambda: task)]
    service = PodcastTranscriptionService(db)

    cancelled = await service.cancel_transcription(task_id=123)

    assert cancelled is False
    db.commit.assert_not_awaited()
