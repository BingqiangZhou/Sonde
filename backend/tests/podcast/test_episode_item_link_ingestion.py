"""Regression tests for episode ingestion with duplicate/missing item links.

Real-world RSS feeds may omit <item><link> entirely or repeat the same
detail-page link across distinct episodes (e.g. Huberman Lab Essentials).
Ingestion must not crash and must stay idempotent across re-parses.
"""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, Mock

import pytest

from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.repositories import PodcastSubscriptionRepository


class _ScalarResult:
    """Small helper to mimic SQLAlchemy scalar results in repository unit tests."""

    def __init__(self, items):
        self._items = items

    def scalars(self):
        return self

    def all(self):
        return self._items

    def first(self):
        return self._items[0] if self._items else None


def _make_db(existing_episodes):
    db = AsyncMock()
    db.execute.return_value = _ScalarResult(existing_episodes)
    db.commit = AsyncMock()
    db.flush = AsyncMock()
    db.refresh = AsyncMock()
    db.add = Mock()
    return db


def _payload(item_link, title, audio_url):
    return {
        "title": title,
        "description": "desc",
        "audio_url": audio_url,
        "published_at": datetime.now(UTC),
        "audio_duration": 60,
        "transcript_url": None,
        "item_link": item_link,
        "metadata": {},
    }


@pytest.mark.asyncio
async def test_batch_with_duplicate_item_links_inserts_all_episodes() -> None:
    """Two distinct episodes sharing one detail-page link both get inserted."""
    db = _make_db([])
    repo = PodcastSubscriptionRepository(db=db, redis=AsyncMock())

    shared_link = "https://example.com/essentials"
    _, new_episodes = await repo.create_or_update_episodes_batch(
        subscription_id=1,
        episodes_data=[
            _payload(shared_link, "Essentials: A", "https://example.com/a.mp3"),
            _payload(shared_link, "Essentials: B", "https://example.com/b.mp3"),
        ],
    )

    assert len(new_episodes) == 2
    assert {ep.title for ep in new_episodes} == {"Essentials: A", "Essentials: B"}
    assert db.add.call_count == 2


@pytest.mark.asyncio
async def test_reparse_with_duplicate_links_updates_in_place_without_growth() -> None:
    """Re-ingesting a feed whose episodes share links matches each incoming item
    to one existing row; no duplicate rows are created."""
    shared_link = "https://example.com/essentials"
    existing_a = PodcastEpisode(
        subscription_id=1,
        title="Essentials: A",
        description="old",
        audio_url="https://example.com/a.mp3",
        published_at=datetime.now(UTC),
        item_link=shared_link,
        status="pending_summary",
        metadata_json={},
    )
    existing_b = PodcastEpisode(
        subscription_id=1,
        title="Essentials: B",
        description="old",
        audio_url="https://example.com/b.mp3",
        published_at=datetime.now(UTC),
        item_link=shared_link,
        status="pending_summary",
        metadata_json={},
    )
    db = _make_db([existing_a, existing_b])
    repo = PodcastSubscriptionRepository(db=db, redis=AsyncMock())

    _, new_episodes = await repo.create_or_update_episodes_batch(
        subscription_id=1,
        episodes_data=[
            _payload(shared_link, "Essentials: A", "https://example.com/a.mp3"),
            _payload(shared_link, "Essentials: B", "https://example.com/b.mp3"),
        ],
    )

    assert new_episodes == []
    assert db.add.call_count == 0
    assert existing_a.audio_url == "https://example.com/a.mp3"
    assert existing_b.audio_url == "https://example.com/b.mp3"


@pytest.mark.asyncio
async def test_batch_with_missing_item_link_inserts_episode() -> None:
    """Feeds omitting <item><link> must still ingest (item_link is nullable)."""
    db = _make_db([])
    repo = PodcastSubscriptionRepository(db=db, redis=AsyncMock())

    _, new_episodes = await repo.create_or_update_episodes_batch(
        subscription_id=1,
        episodes_data=[_payload(None, "No link episode", "https://example.com/c.mp3")],
    )

    assert len(new_episodes) == 1
    assert new_episodes[0].item_link is None


@pytest.mark.asyncio
async def test_get_episode_by_item_link_returns_first_on_duplicates() -> None:
    """Single-episode lookup must not raise when several rows share a link."""
    shared_link = "https://example.com/essentials"
    first = PodcastEpisode(
        subscription_id=1,
        title="First",
        description="",
        audio_url="https://example.com/a.mp3",
        published_at=datetime.now(UTC),
        item_link=shared_link,
        status="pending_summary",
        metadata_json={},
    )
    second = PodcastEpisode(
        subscription_id=1,
        title="Second",
        description="",
        audio_url="https://example.com/b.mp3",
        published_at=datetime.now(UTC),
        item_link=shared_link,
        status="pending_summary",
        metadata_json={},
    )
    db = _make_db([first, second])
    repo = PodcastSubscriptionRepository(db=db, redis=AsyncMock())

    episode = await repo.get_episode_by_item_link(1, shared_link)

    assert episode is first
