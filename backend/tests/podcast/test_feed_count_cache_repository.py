import time
from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.repositories import PodcastRepository
from app.domains.podcast.repositories.feed_repository import (
    _feed_count_cache as feed_count_cache,
)


class _ScalarResult:
    def __init__(self, value):
        self._value = value

    def scalar(self):
        return self._value


@pytest.fixture(autouse=True)
def _clean_cache():
    feed_count_cache.clear()
    yield
    feed_count_cache.clear()


@pytest.mark.asyncio
async def test_feed_total_count_uses_cache_hit_without_db():
    db = AsyncMock()
    # Fresh cache entry: expires far in the future.
    feed_count_cache[99] = (time.monotonic() + 120, 11)

    repo = PodcastRepository(db=db)
    total = await repo._get_feed_total_count(user_id=99)

    assert total == 11
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
async def test_feed_total_count_caches_db_result_on_miss():
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_ScalarResult(5))

    repo = PodcastRepository(db=db)
    total = await repo._get_feed_total_count(user_id=2)

    assert total == 5
    db.execute.assert_awaited_once()
    expires_at, cached = feed_count_cache[2]
    assert cached == 5
    assert expires_at > time.monotonic()


@pytest.mark.asyncio
async def test_feed_total_count_expired_entry_queries_db_again():
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_ScalarResult(7))
    # Stale cache entry: already expired.
    feed_count_cache[3] = (time.monotonic() - 1, 99)

    repo = PodcastRepository(db=db)
    total = await repo._get_feed_total_count(user_id=3)

    assert total == 7
    db.execute.assert_awaited_once()
