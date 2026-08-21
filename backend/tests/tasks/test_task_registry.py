"""Celery task registry and schedule snapshot checks."""

from app.core.celery_app import celery_app


def test_registered_task_names_snapshot() -> None:
    registered_names = set(celery_app.tasks.keys())
    expected_names = {
        "app.domains.podcast.tasks.tasks_subscription.refresh_all_podcast_feeds",
        "app.domains.podcast.tasks.tasks_summary.generate_pending_summaries",
        "app.domains.podcast.tasks.tasks_transcription.process_audio_transcription",
        "app.domains.podcast.tasks.tasks_transcription.process_podcast_episode_with_transcription",
        "app.domains.podcast.tasks.tasks_transcription.process_pending_transcriptions",
        "app.domains.podcast.tasks.tasks_maintenance.cleanup_old_playback_states",
        "app.domains.podcast.tasks.tasks_maintenance.cleanup_old_transcription_temp_files",
        "app.domains.podcast.tasks.tasks_maintenance.auto_cleanup_cache_files",
        "app.domains.podcast.tasks.tasks_daily_report.generate_daily_podcast_reports",
    }
    assert expected_names.issubset(registered_names)


def test_beat_schedule_references_registered_tasks() -> None:
    registered_names = set(celery_app.tasks.keys())
    beat_schedule = celery_app.conf.beat_schedule

    assert beat_schedule

    for beat_name, beat_item in beat_schedule.items():
        task_name = beat_item["task"]
        assert task_name in registered_names, (
            f"{beat_name} references unregistered task"
        )
        # Single-queue mode: every beat entry targets the default queue.
        assert beat_item["options"]["queue"] == "default", (
            f"{beat_name} should use default queue in single-user mode"
        )


def test_beat_schedule_snapshot() -> None:
    beat_schedule = celery_app.conf.beat_schedule

    assert "refresh-podcast-feeds" in beat_schedule
    assert "generate-pending-summaries" in beat_schedule
    assert "auto-cleanup-cache" in beat_schedule
    assert "generate-daily-podcast-reports" in beat_schedule
