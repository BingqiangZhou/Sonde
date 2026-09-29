"""Summary task flow tests."""

from contextlib import asynccontextmanager

from app.domains.podcast.tasks import tasks_summary as summary_generation


@asynccontextmanager
async def _worker_session_factory(session_obj):
    yield session_obj


async def test_generate_pending_summaries_delegates_to_workflow(monkeypatch):
    class _FakeWorkflow:
        def __init__(self, session):
            self.session = session

        async def generate_pending_summaries_run(self):
            return {"status": "success", "processed": 1, "failed": 0}

    monkeypatch.setattr(
        "app.domains.podcast.tasks.tasks_summary.SummaryWorkflowService",
        _FakeWorkflow,
    )

    result = await summary_generation.generate_pending_summaries(timestamp=0)
    assert result == {"status": "success", "processed": 1, "failed": 0}


async def test_generate_episode_summary_delegates_to_workflow(monkeypatch):
    monkeypatch.setattr(
        summary_generation,
        "worker_session",
        lambda *_args, **_kwargs: _worker_session_factory(object()),
    )

    class _FakeWorkflow:
        def __init__(self, session):
            self.session = session

        async def execute_episode_summary_generation(
            self,
            episode_id,
            *,
            summary_model=None,
            custom_prompt=None,
        ):
            return {
                "episode_id": episode_id,
                "summary_model": summary_model,
                "custom_prompt": custom_prompt,
            }

    monkeypatch.setattr(summary_generation, "SummaryWorkflowService", _FakeWorkflow)

    result = await summary_generation.generate_episode_summary(
        episode_id=15,
        summary_model="model-a",
        custom_prompt="prompt",
    )

    assert result["episode_id"] == 15


def test_summary_tasks_configure_exponential_retry() -> None:
    """Both summary tasks retry with the Celery-parity backoff policy."""
    pending_task = summary_generation.generate_pending_summaries
    episode_task = summary_generation.generate_episode_summary
    for task in (pending_task, episode_task):
        strategy = task.retry_strategy
        assert strategy is not None
        assert strategy.max_attempts == 4
