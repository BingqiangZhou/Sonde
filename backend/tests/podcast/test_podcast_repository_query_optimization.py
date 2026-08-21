"""Fast tests for podcast repository query optimizations."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.domains.podcast.repositories import PodcastRepository


class _RowsResult:
    def __init__(self, rows):
        self._rows = rows

    def unique(self):
        return self

    def all(self):
        return self._rows


class _ScalarRowsResult:
    def __init__(self, values):
        self._values = values

    def unique(self):
        return self

    def scalars(self):
        return self

    def all(self):
        return self._values


class _MappingRowsResult:
    def __init__(self, rows):
        self._rows = rows

    def mappings(self):
        return self

    def all(self):
        return self._rows


@pytest.mark.asyncio
async def test_subscription_episodes_batch_uses_topn_window_query():
    db = AsyncMock()
    redis = AsyncMock()
    episode_a = MagicMock(subscription_id=1)
    episode_b = MagicMock(subscription_id=1)
    episode_c = MagicMock(subscription_id=2)
    db.execute.return_value = _ScalarRowsResult([episode_a, episode_b, episode_c])

    repo = PodcastRepository(db=db, redis=redis)
    result = await repo.get_subscription_episodes_batch(
        [1, 2], limit_per_subscription=2
    )

    assert result == {1: [episode_a, episode_b], 2: [episode_c]}
    executed_query = db.execute.await_args.args[0]
    sql = str(executed_query).lower()
    assert "row_number()" in sql
    assert "partition by" in sql


@pytest.mark.asyncio
async def test_user_subscriptions_paginated_returns_counts_without_fallback():
    db = AsyncMock()
    redis = AsyncMock()

    sub1 = MagicMock()
    sub1.id = 101
    sub2 = MagicMock()
    sub2.id = 202
    db.execute.return_value = _RowsResult([(sub1, 7, 2), (sub2, 3, 2)])

    repo = PodcastRepository(db=db, redis=redis)
    items, total, counts = await repo.get_user_subscriptions_paginated(
        user_id=1, page=1, size=20
    )

    assert items == [sub1, sub2]
    assert total == 2
    assert counts == {101: 7, 202: 3}
    assert db.scalar.await_count == 0


@pytest.mark.asyncio
async def test_user_subscriptions_paginated_uses_fallback_on_empty_page():
    db = AsyncMock()
    redis = AsyncMock()
    db.execute.return_value = _RowsResult([])
    db.scalar.return_value = 5

    repo = PodcastRepository(db=db, redis=redis)
    items, total, counts = await repo.get_user_subscriptions_paginated(
        user_id=1, page=3, size=20
    )

    assert items == []
    assert total == 5
    assert counts == {}
    assert db.scalar.await_count == 1


@pytest.mark.asyncio
async def test_feed_lightweight_cursor_reuses_feed_total_cache_path():
    db = AsyncMock()
    redis = AsyncMock()
    db.execute.return_value = _MappingRowsResult([])

    repo = PodcastRepository(db=db, redis=redis)
    repo._get_feed_total_count = AsyncMock(return_value=9)

    (
        items,
        total,
        has_more,
        next_cursor,
    ) = await repo.get_feed_lightweight_cursor_paginated(
        user_id=1,
        size=20,
        cursor_published_at=datetime.now(UTC),
        cursor_episode_id=999,
    )

    assert items == []
    assert total == 9
    assert has_more is False
    assert next_cursor is None
    repo._get_feed_total_count.assert_awaited_once_with(1)
    assert db.execute.await_count == 1
