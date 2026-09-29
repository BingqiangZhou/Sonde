"""Pending-transcription backlog task flow tests."""

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock

from app.domains.podcast.tasks import tasks_transcription as pending_transcription
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)


@asynccontextmanager
async def _fake_worker_session(session_obj):
    yield session_obj


async def test_backlog_task_dispatches_candidates(monkeypatch):
    expected = {
        "status": "success",
        "total_candidates": 37,
        "checked": 3,
        "dispatched": 3,
        "skipped": 0,
        "failed": 0,
        "skipped_reasons": {},
    }
    monkeypatch.setattr(
        pending_transcription,
        "worker_session",
        lambda: _fake_worker_session(object()),
    )
    monkeypatch.setattr(
        PodcastTaskOrchestrationService,
        "process_pending_transcriptions",
        AsyncMock(return_value=expected),
    )

    result = await pending_transcription.process_pending_transcriptions()
    assert result == expected
