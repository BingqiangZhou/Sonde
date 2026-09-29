"""Procrastinate task registry and periodic schedule snapshot checks."""

import app.domains.podcast.tasks  # noqa: F401  (registers tasks + schedules)
from app.core.jobs import procrastinate_app


def test_registered_task_names_snapshot() -> None:
    registered_names = set(procrastinate_app.tasks.keys())
    expected_names = {
        "podcast.subscription.refresh_all_feeds",
        "podcast.summary.generate_pending",
        "podcast.summary.generate_episode",
        "podcast.transcription.process_audio",
        "podcast.transcription.process_episode",
        "podcast.transcription.process_pending",
        "podcast.maintenance.cleanup_old_playback_states",
        "podcast.maintenance.cleanup_old_transcription_temp_files",
        "podcast.maintenance.auto_cleanup_cache",
        "podcast.maintenance.process_opml_subscription_episodes",
        "podcast.report.generate_daily",
    }
    assert expected_names.issubset(registered_names)


def test_periodic_registry_references_registered_tasks() -> None:
    registered_names = set(procrastinate_app.tasks.keys())
    periodic_tasks = procrastinate_app.periodic_registry.periodic_tasks

    assert periodic_tasks

    for (task_name, periodic_id), periodic_task in periodic_tasks.items():
        assert task_name in registered_names, (
            f"{periodic_id} references unregistered task"
        )
        # Single-queue mode: every task targets the default queue.
        assert periodic_task.task.queue == "default", (
            f"{periodic_id} should use default queue in single-user mode"
        )


def test_periodic_schedule_snapshot() -> None:
    periodic_tasks = procrastinate_app.periodic_registry.periodic_tasks

    # Cron schedules keep UTC semantics (the worker container pins TZ=UTC),
    # matching the former Celery beat entries.
    expected = {
        "refresh-podcast-feeds": "0 * * * *",
        "generate-pending-summaries": "*/30 * * * *",
        "auto-cleanup-cache": "0 4 * * *",
        "generate-daily-podcast-reports": "30 19 * * *",
    }
    actual = {
        periodic_id: periodic_task.cron
        for (_task_name, periodic_id), periodic_task in periodic_tasks.items()
    }
    assert actual == expected
