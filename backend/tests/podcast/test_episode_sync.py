"""Incremental episode sync projection tests (client-cache hydration)."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.services.episode_service import PodcastEpisodeService


def _sync_row(now: datetime, episode_id: int, summary: str, description: str) -> dict:
    return {
        "id": episode_id,
        "subscription_id": 10,
        "subscription_title": "Test Sub",
        "subscription_image_url": "https://example.com/sub.jpg",
        "title": f"Episode {episode_id}",
        "description": description,
        "audio_url": "https://example.com/audio.mp3",
        "audio_duration": 1200,
        "audio_file_size": 100,
        "published_at": now,
        "image_url": "https://example.com/ep.jpg",
        "item_link": "https://example.com/item",
        "transcript_url": None,
        "transcript_content": "full transcript",
        "ai_summary": summary,
        "ai_confidence_score": 0.8,
        "play_count": 0,
        "last_played_at": None,
        "season": None,
        "episode_number": None,
        "explicit": False,
        "status": "published",
        "metadata": {},
        "playback_position": None,
        "is_playing": False,
        "playback_rate": 1.0,
        "is_played": False,
        "created_at": now,
        "updated_at": now,
    }


@pytest.mark.asyncio
async def test_list_sync_keeps_ai_summary_and_collapses_description():
    now = datetime.now(UTC)
    long_description = "  line1  \n\n line2\t" + "x" * 400
    service = PodcastEpisodeService(db=AsyncMock(), user_id=42)
    service.repo = AsyncMock()
    service.repo.get_feed_sync_paginated.return_value = (
        [_sync_row(now, 1, "full summary text", long_description)],
        False,
        (now, 1),
    )

    items, has_more, next_cursor = await service.list_sync(size=50)

    assert has_more is False
    assert next_cursor == (now, 1)
    assert len(items) == 1
    # Feed-style collapsing applies to the description...
    assert len(items[0]["description"]) <= 320
    assert "  " not in items[0]["description"]
    # ...but the summary stays intact for offline rendering.
    assert items[0]["ai_summary"] == "full summary text"
    assert items[0]["transcript_content"] is None
    service.repo.get_feed_sync_paginated.assert_awaited_once_with(
        42, size=50, cursor_updated_at=None, cursor_episode_id=None
    )


@pytest.mark.asyncio
async def test_list_sync_forwards_keyset_cursor():
    now = datetime.now(UTC)
    service = PodcastEpisodeService(db=AsyncMock(), user_id=7)
    service.repo = AsyncMock()
    service.repo.get_feed_sync_paginated.return_value = ([], False, None)

    await service.list_sync(size=100, cursor_updated_at=now, cursor_episode_id=9)

    service.repo.get_feed_sync_paginated.assert_awaited_once_with(
        7, size=100, cursor_updated_at=now, cursor_episode_id=9
    )


@pytest.mark.asyncio
async def test_list_sync_empty_batch_returns_none_cursor():
    """No rows → keep the client's previous watermark (cursor stays None)."""
    service = PodcastEpisodeService(db=AsyncMock(), user_id=1)
    service.repo = AsyncMock()
    service.repo.get_feed_sync_paginated.return_value = ([], False, None)

    items, has_more, next_cursor = await service.list_sync()

    assert items == []
    assert has_more is False
    assert next_cursor is None


@pytest.mark.asyncio
async def test_list_sync_has_more_keeps_tail_cursor():
    """The tail cursor is reported even on the final page — it is the
    watermark the client persists for its next incremental sync."""
    now = datetime.now(UTC)
    service = PodcastEpisodeService(db=AsyncMock(), user_id=1)
    service.repo = AsyncMock()
    service.repo.get_feed_sync_paginated.return_value = (
        [_sync_row(now, 5, "s5", "d5"), _sync_row(now, 6, "s6", "d6")],
        True,
        (now, 6),
    )

    items, has_more, next_cursor = await service.list_sync(size=2)

    assert has_more is True
    assert next_cursor == (now, 6)
    assert [item["id"] for item in items] == [5, 6]
