"""Celery configuration snapshot checks."""

from app.core.celery_app import celery_app


def test_celery_beat_schedule_snapshot() -> None:
    beat_schedule = celery_app.conf.beat_schedule

    assert "refresh-podcast-feeds" in beat_schedule
    assert "generate-pending-summaries" in beat_schedule
    assert "auto-cleanup-cache" in beat_schedule
    # Phase C：评分兜底 + 三刊（Asia/Shanghai）
    assert "insight-analyze-sweep" in beat_schedule
    assert "insight-reports-daily" in beat_schedule
    assert "insight-reports-weekly" in beat_schedule
    assert "insight-reports-monthly" in beat_schedule
    assert "insight-reports-catchup" in beat_schedule
    assert "generate-daily-podcast-reports" not in beat_schedule
    assert celery_app.conf.timezone == "Asia/Shanghai"
