"""三刊窗口计算单测（Asia/Shanghai 日历；DB 存 UTC）。"""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.domains.insight.report_service import (
    default_report_key,
    range_label,
    report_window,
)


UTC = ZoneInfo("UTC")
SH = ZoneInfo("Asia/Shanghai")


def test_daily_window_spans_shanghai_day():
    start, end = report_window("daily", "2026-10-27")
    # 2026-10-27 00:00 Shanghai == 2026-10-26 16:00 UTC
    assert start == datetime(2026, 10, 26, 16, 0, tzinfo=UTC)
    assert end == datetime(2026, 10, 27, 16, 0, tzinfo=UTC)


def test_weekly_window_starts_monday():
    start, end = report_window("weekly", "2026-10-26")  # 周一
    assert start == datetime(2026, 10, 25, 16, 0, tzinfo=UTC)
    assert end == datetime(2026, 11, 1, 16, 0, tzinfo=UTC)


def test_monthly_window():
    start, end = report_window("monthly", "2026-10")
    assert start == datetime(2026, 9, 30, 16, 0, tzinfo=UTC)
    assert end == datetime(2026, 10, 31, 16, 0, tzinfo=UTC)  # 11-01 00:00 SH


def test_monthly_window_across_year():
    start, end = report_window("monthly", "2026-12")
    assert end == datetime(2026, 12, 31, 16, 0, tzinfo=UTC)  # 2027-01-01 00:00 SH


def test_default_keys_use_previous_period():
    # daily：昨天；weekly：上一个周一；monthly：上个月
    now = datetime.now(SH)
    daily = default_report_key("daily")
    assert daily == (now.date().fromordinal(now.date().toordinal() - 1)).isoformat()
    weekly = default_report_key("weekly")
    weekly_start = datetime.strptime(weekly, "%Y-%m-%d").date()
    assert weekly_start.weekday() == 0
    assert weekly_start < now.date() - __import__("datetime").timedelta(days=now.weekday())
    monthly = default_report_key("monthly")
    assert monthly != now.strftime("%Y-%m")


def test_range_labels():
    assert range_label("daily", "2026-10-27") == "2026-10-27"
    assert range_label("weekly", "2026-10-20") == "2026-10-20 ~ 2026-10-26"
    assert range_label("monthly", "2026-10") == "2026-10"


def test_unknown_kind_rejected():
    with pytest.raises(ValueError):
        report_window("quarterly", "2026-Q4")
