"""Real-stack integration tests for the previously broken hot paths.

Drive the actual service/repository code against real postgres (FKs, unique
constraints, row locks, JSON columns) and real redis (locks, dispatch
claims, feed-count cache) — exactly the layer the sqlite+mock suite could
not cover.
"""

from datetime import UTC, datetime

import pytest
import pytest_asyncio
from sqlalchemy import select

from app.core.redis import RedisCache
from app.domains.auth.models import User
from app.domains.podcast.models import (
    PodcastEpisode,
    TranscriptionTask,
)
from app.domains.podcast.repositories.podcast_repository import PodcastRepository
from app.domains.podcast.services.playback_service import PodcastPlaybackService
from app.domains.podcast.transcription.state import (
    claim_task_dispatch,
    clear_task_dispatch,
)


def _episodes_payload(n: int) -> list[dict]:
    return [
        {
            "title": f"Episode {i}",
            "description": "integration desc",
            "audio_url": f"https://example.com/int-ep{i}.mp3",
            "published_at": datetime.now(UTC),
            "audio_duration": 60 + i,
            "transcript_url": None,
            "item_link": f"https://example.com/int/ep{i}",
            "metadata": {},
        }
        for i in range(1, n + 1)
    ]


@pytest_asyncio.fixture
async def seeded_user(db_session) -> int:
    user = User(
        email="integration@example.com",
        username="integration_user",
        hashed_password="x",
    )
    db_session.add(user)
    await db_session.commit()
    return user.id


@pytest.mark.integration
async def test_atomic_ingest_on_real_postgres(db_session, seeded_user):
    repo = PodcastRepository(db_session)

    subscription, _, new = await repo.add_subscription_with_episodes(
        user_id=seeded_user,
        feed_url="https://example.com/int-feed.xml",
        title="Integration Cast",
        description="desc",
        metadata={"platform": "generic"},
        episodes_data=_episodes_payload(3),
    )

    assert subscription.id is not None
    assert len(new) == 3
    persisted = (
        await db_session.execute(
            select(PodcastEpisode).where(
                PodcastEpisode.subscription_id == subscription.id
            )
        )
    ).scalars().all()
    assert len(persisted) == 3


@pytest.mark.integration
async def test_playback_upsert_twice_with_row_locks(db_session, seeded_user):
    repo = PodcastRepository(db_session)
    subscription, _, new = await repo.add_subscription_with_episodes(
        user_id=seeded_user,
        feed_url="https://example.com/int-feed-2.xml",
        title="Playback Cast",
        description="d",
        metadata={},
        episodes_data=_episodes_payload(1),
    )
    episode = new[0]
    service = PodcastPlaybackService(db_session, seeded_user)

    first = await service.update_playback_progress(
        episode.id, progress_seconds=30, is_playing=True, playback_rate=1.0
    )
    second = await service.update_playback_progress(
        episode.id, progress_seconds=90, is_playing=False, playback_rate=1.5
    )

    assert first["current_position"] == 30
    assert second["current_position"] == 90
    assert second["playback_rate"] == 1.5
    assert second["play_count"] == 1  # is_playing=False doesn't bump count


@pytest.mark.integration
async def test_dispatch_claim_duplicate_raises_then_recovers(
    db_session, seeded_user, real_redis: RedisCache
):
    repo = PodcastRepository(db_session)
    _, _, new = await repo.add_subscription_with_episodes(
        user_id=seeded_user,
        feed_url="https://example.com/int-dispatch.xml",
        title="Dispatch Cast",
        description="d",
        metadata={},
        episodes_data=_episodes_payload(1),
    )
    task = TranscriptionTask(
        episode_id=new[0].id,
        status="pending",
        current_step="not_started",
        original_audio_url=new[0].audio_url,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task_id = task.id

    assert await claim_task_dispatch(real_redis, db_session, task_id) is True

    with pytest.raises(RuntimeError, match="dispatch key exists"):
        await claim_task_dispatch(real_redis, db_session, task_id)

    await clear_task_dispatch(real_redis, task_id)
    assert await claim_task_dispatch(real_redis, db_session, task_id) is True


@pytest.mark.integration
async def test_feed_count_cache_roundtrip_on_real_redis(
    db_session, seeded_user, real_redis: RedisCache
):
    repo = PodcastRepository(db_session, redis=real_redis)
    subscription, _, _ = await repo.add_subscription_with_episodes(
        user_id=seeded_user,
        feed_url="https://example.com/int-feed-3.xml",
        title="Cache Cast",
        description="d",
        metadata={},
        episodes_data=_episodes_payload(2),
    )

    page1, total1, _, _ = await repo.get_feed_lightweight_cursor_paginated(
        seeded_user, size=1
    )
    page2, total2, _, _ = await repo.get_feed_lightweight_cursor_paginated(
        seeded_user, size=1
    )

    assert total1 == total2 == 2
    assert len(page1) == len(page2) == 1
    # The count cache key for this user must now exist in redis.
    exists = await real_redis.exists(
        f"podcast:feed:count:{seeded_user}"
    )
    assert exists is True


@pytest.mark.integration
async def test_search_returns_scored_rows_on_postgres(db_session, seeded_user):
    repo = PodcastRepository(db_session)
    payload = _episodes_payload(2)
    payload[0]["title"] = "Integration searchable episode about postgres"
    payload[0]["item_link"] = "https://example.com/int/searchable"
    await repo.add_subscription_with_episodes(
        user_id=seeded_user,
        feed_url="https://example.com/int-feed-4.xml",
        title="Search Cast",
        description="d",
        metadata={},
        episodes_data=payload,
    )

    scored, total = await repo.search_episodes(
        seeded_user, query="postgres", search_in="title", page=1, size=10
    )

    assert total >= 1
    assert all(isinstance(score, float) for _, score in scored)


@pytest.mark.integration
async def test_unique_item_link_constraint_across_batches(db_session, seeded_user):
    repo = PodcastRepository(db_session)
    subscription, _, _ = await repo.add_subscription_with_episodes(
        user_id=seeded_user,
        feed_url="https://example.com/int-feed-5.xml",
        title="Unique Cast",
        description="d",
        metadata={},
        episodes_data=_episodes_payload(1),
    )

    # Same item_link, second batch hits the DB-level unique constraint path
    # and must be treated as an update, not an insert.
    _, new = await repo.create_or_update_episodes_batch(
        subscription_id=subscription.id, episodes_data=_episodes_payload(1)
    )

    assert new == []
