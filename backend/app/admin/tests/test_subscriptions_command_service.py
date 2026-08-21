from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.admin.services.subscriptions_service import (
    SUBSCRIPTION_TEST_PREVIEW_LIMIT,
    AdminSubscriptionsService,
)


class _ScalarOneOrNoneResult:
    def __init__(self, value):
        self._value = value

    def scalar_one_or_none(self):
        return self._value


class _ExecuteResult:
    def __init__(self, *, rowcount: int):
        self.rowcount = rowcount


@pytest.mark.asyncio
async def test_update_frequency_uses_bulk_update(monkeypatch):
    db = AsyncMock()
    existing_setting = SimpleNamespace(value={})
    db.execute = AsyncMock(
        side_effect=[
            _ScalarOneOrNoneResult(existing_setting),
            _ExecuteResult(rowcount=7),
        ],
    )

    service = AdminSubscriptionsService(db)
    result = await service.update_frequency(
        request=SimpleNamespace(),
        user_id=1,
        update_frequency="DAILY",
        update_time="09:30",
        update_day=None,
    )

    assert result["success"] is True
    assert "7 user subscriptions" in result["message"]
    update_stmt = db.execute.await_args_list[1].args[0]
    assert str(update_stmt).lower().startswith("update ")


@pytest.mark.asyncio
async def test_test_subscription_url_returns_preview_counts(monkeypatch):
    fake_feed = SimpleNamespace(
        title="Test Feed",
        description="Example",
        episodes=[
            SimpleNamespace(title=f"Entry {index}")
            for index in range(SUBSCRIPTION_TEST_PREVIEW_LIMIT)
        ],
    )
    fetch_and_parse_feed = AsyncMock(return_value=(True, fake_feed, None))
    monkeypatch.setattr(
        "app.domains.podcast.integration.secure_rss_parser.SecureRSSParser",
        lambda user_id: SimpleNamespace(
            fetch_and_parse_feed=fetch_and_parse_feed,
        ),
    )

    service = AdminSubscriptionsService(AsyncMock())
    payload, status_code = await service.test_subscription_url(
        source_url="https://example.com/feed.xml",
        username="admin",
    )

    assert status_code == 200
    assert payload["entry_count"] == SUBSCRIPTION_TEST_PREVIEW_LIMIT
    assert payload["total_entry_count"] == SUBSCRIPTION_TEST_PREVIEW_LIMIT
    fetch_and_parse_feed.assert_awaited_once()
    assert fetch_and_parse_feed.await_args.kwargs["max_episodes"] == (
        SUBSCRIPTION_TEST_PREVIEW_LIMIT
    )
