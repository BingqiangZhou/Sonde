"""Import/runtime smoke tests for lazy startup boundaries."""

import app.domains.podcast.tasks  # noqa: F401  (registers tasks + schedules)
from app.core.jobs import procrastinate_app
from app.domains.podcast.tasks.runtime import worker_session
from app.main import app, create_application


def test_app_import_and_factory_smoke() -> None:
    assert app is not None
    created = create_application()
    assert created.title


def test_admin_router_import_smoke() -> None:
    """Admin router still imports cleanly after the page diet."""
    from app.admin.router import router

    assert router.routes


def test_queue_app_task_registration_smoke() -> None:
    assert len(procrastinate_app.periodic_registry.periodic_tasks) == 4
    assert "podcast.transcription.process_audio" in procrastinate_app.tasks


def test_worker_runtime_exports_session_factory() -> None:
    assert callable(worker_session)
