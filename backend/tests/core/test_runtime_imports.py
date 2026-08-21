"""Import/runtime smoke tests for lazy startup boundaries."""

from app.core.celery_app import create_celery_app
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


def test_celery_app_lazy_creation_smoke() -> None:
    celery_app = create_celery_app()
    assert celery_app.conf.beat_schedule
    assert len(celery_app.conf.beat_schedule) == 4


def test_worker_runtime_exports_session_factory() -> None:
    assert callable(worker_session)
