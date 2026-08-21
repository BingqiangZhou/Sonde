from datetime import UTC, datetime
from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.services.episode_service import PodcastEpisodeService


def _feed_item(now: datetime, description: str) -> dict:
    return {
        "id": 1,
        "subscription_id": 10,
        "subscription_title": "Test Sub",
        "subscription_image_url": "https://example.com/sub.jpg",
        "title": "Episode",
        "description": description,
        "audio_url": "https://example.com/audio.mp3",
        "audio_duration": 1200,
        "audio_file_size": 100,
        "published_at": now,
        "image_url": "https://example.com/ep.jpg",
        "item_link": "https://example.com/item",
        "transcript_url": "https://example.com/transcript",
        "transcript_content": "full transcript",
        "ai_summary": "full summary",
        "summary_version": "1.0",
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
async def test_list_feed_normalizes_payload():
    now = datetime.now(UTC)
    long_description = f"  line1  \n\n line2\t{('x' * 400)}  "

    service = PodcastEpisodeService(db=AsyncMock(), user_id=42)
    service.repo = AsyncMock()
    service.repo.get_feed_lightweight_cursor_paginated.return_value = (
        [_feed_item(now, long_description)],
        1,
        False,
        None,
    )

    items, total, has_more, next_cursor = await service.list_feed(size=20)

    assert total == 1
    assert has_more is False
    assert next_cursor is None
    assert len(items) == 1
    assert len(items[0]["description"]) <= 320
    assert "  " not in items[0]["description"]
    assert items[0]["transcript_content"] is None
    assert items[0]["ai_summary"] is None
    service.repo.get_feed_lightweight_cursor_paginated.assert_awaited_once_with(
        42,
        size=20,
        cursor_published_at=None,
        cursor_episode_id=None,
    )


@pytest.mark.asyncio
async def test_list_feed_forwards_cursor_values():
    now = datetime.now(UTC)
    service = PodcastEpisodeService(db=AsyncMock(), user_id=7)
    service.repo = AsyncMock()
    service.repo.get_feed_lightweight_cursor_paginated.return_value = (
        [],
        0,
        False,
        None,
    )

    await service.list_feed(size=5, cursor_published_at=now, cursor_episode_id=9)

    service.repo.get_feed_lightweight_cursor_paginated.assert_awaited_once_with(
        7,
        size=5,
        cursor_published_at=now,
        cursor_episode_id=9,
    )
