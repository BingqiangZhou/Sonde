"""Transcript/summary content must come from the canonical stores."""

from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.models import TranscriptionStatus
from app.domains.podcast.routes.transcription_route_common import (
    build_transcription_response,
)
from app.domains.podcast.services.transcription_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.utils.status_helpers import status_value


def _make_workflow() -> TranscriptionWorkflowService:
    return TranscriptionWorkflowService(
        AsyncMock(),
        engine_factory=lambda _db: AsyncMock(),
    )


@pytest.mark.asyncio
async def test_transcript_content_reads_from_transcript_table():
    workflow = _make_workflow()
    workflow.db.execute.side_effect = None
    workflow.db.execute.return_value = SimpleNamespace(
        scalar_one_or_none=lambda: "canonical transcript body"
    )

    content = await workflow.get_episode_transcript_content(7)

    assert content == "canonical transcript body"
    stmt = workflow.db.execute.await_args.args[0]
    assert "podcast_episode_transcripts" in str(stmt)


@pytest.mark.asyncio
async def test_schedule_preview_uses_canonical_transcript():
    workflow = _make_workflow()
    workflow._get_episode = AsyncMock(
        return_value=SimpleNamespace(id=7, title="Ep", ai_summary="sum")
    )
    workflow.start_transcription = AsyncMock(
        return_value={
            "task": SimpleNamespace(
                id=3, transcript_content="stale task copy", status="completed"
            ),
            "action": "reused_completed",
        }
    )
    workflow.get_episode_transcript_content = AsyncMock(
        return_value="canonical " + "x" * 200
    )

    result = await workflow.schedule_transcription(episode_id=7, force=False)

    assert result["status"] == "skipped"
    preview = result["transcript_content"]
    assert preview.startswith("canonical")
    assert len(preview) == 100 + len("...")
    assert "stale task copy" not in preview


@pytest.mark.asyncio
async def test_status_flags_use_canonical_stores():
    workflow = _make_workflow()
    task = SimpleNamespace(
        id=3,
        status=TranscriptionStatus.COMPLETED,
        progress_percentage=100.0,
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
        completed_at=datetime.now(UTC),
        transcript_word_count=42,
        summary_word_count=7,
        error_message=None,
    )
    workflow._get_episode = AsyncMock(
        return_value=SimpleNamespace(id=7, title="Ep", ai_summary="existing summary")
    )
    workflow._get_existing_transcription_task = AsyncMock(return_value=task)
    workflow.get_episode_transcript_content = AsyncMock(return_value="the transcript")

    result = await workflow.get_transcription_status(7)

    assert result["has_transcript"] is True
    assert result["transcript_preview"].startswith("the transcript")
    assert result["has_summary"] is True


@pytest.mark.asyncio
async def test_status_flags_false_without_canonical_content():
    workflow = _make_workflow()
    task = SimpleNamespace(
        id=3,
        status=TranscriptionStatus.COMPLETED,
        progress_percentage=100.0,
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
        completed_at=datetime.now(UTC),
        transcript_word_count=None,
        summary_word_count=None,
        error_message=None,
    )
    workflow._get_episode = AsyncMock(
        return_value=SimpleNamespace(id=7, title="Ep", ai_summary=None)
    )
    workflow._get_existing_transcription_task = AsyncMock(return_value=task)
    workflow.get_episode_transcript_content = AsyncMock(return_value=None)

    result = await workflow.get_transcription_status(7)

    assert result["has_transcript"] is False
    assert result["transcript_preview"] is None
    assert result["has_summary"] is False


def test_build_transcription_response_sources_content_from_canonical_args():
    now = datetime.now(UTC)
    task = SimpleNamespace(
        id=3,
        episode_id=7,
        status=TranscriptionStatus.COMPLETED,
        progress_percentage=100.0,
        original_audio_url="https://example.com/a.mp3",
        original_file_size=1000,
        transcript_word_count=42,
        transcript_duration=None,
        transcript_content="stale task copy",
        error_message=None,
        error_code=None,
        download_time=1.0,
        conversion_time=1.0,
        transcription_time=1.0,
        chunk_size_mb=10,
        model_used="whisper-1",
        created_at=now,
        started_at=now,
        completed_at=now,
        updated_at=now,
        duration_seconds=None,
        total_processing_time=None,
        summary_content="stale task summary",
        summary_model_used="gpt",
        summary_word_count=5,
        summary_processing_time=1.0,
        summary_error_message=None,
        chunk_info=None,
    )
    episode = SimpleNamespace(
        id=7,
        title="Ep",
        audio_url="https://example.com/a.mp3",
        audio_duration=600,
        ai_summary="canonical summary",
    )

    response = build_transcription_response(
        task,
        episode,
        transcript_content="canonical transcript",
    )

    assert response.transcript_content == "canonical transcript"
    assert response.summary_content == "canonical summary"
    assert status_value(response.status) == "completed"
