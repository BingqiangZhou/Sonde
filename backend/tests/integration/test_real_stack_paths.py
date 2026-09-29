"""Real-stack integration tests for the previously broken hot paths.

Drive the actual service/repository code against real postgres (FKs, unique
constraints, row locks, JSON columns), the Postgres advisory locks and the
procrastinate queue — exactly the layer the sqlite+mock suite could not
cover.
"""

from datetime import UTC, datetime

import pytest
import pytest_asyncio
from sqlalchemy import select

from app.domains.podcast.models import (
    PodcastEpisode,
    TranscriptionTask,
)
from app.domains.podcast.repositories.feed_repository import (
    _feed_count_cache as feed_count_cache,
)
from app.domains.podcast.repositories.podcast_repository import PodcastRepository
from app.domains.podcast.transcription.state import (
    UNKNOWN_OWNER_TASK_ID,
    TranscriptionStateManager,
    claim_task_dispatch,
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
    """Seed the operator row; the users table has no ORM model anymore."""
    from sqlalchemy import text

    await db_session.execute(
        text(
            "INSERT INTO users (email, username, hashed_password, created_at, updated_at) "
            "VALUES ('integration@example.com', 'integration_user', 'x', "
            "CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) "
            "ON CONFLICT (email) DO NOTHING"
        )
    )
    await db_session.commit()
    result = await db_session.execute(
        text("SELECT id FROM users WHERE email = 'integration@example.com'")
    )
    return int(result.scalar_one())


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
        (
            await db_session.execute(
                select(PodcastEpisode).where(
                    PodcastEpisode.subscription_id == subscription.id
                )
            )
        )
        .scalars()
        .all()
    )
    assert len(persisted) == 3


@pytest.mark.integration
async def test_dispatch_claim_status_semantics(db_session, seeded_user):
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

    # Pending tasks may execute.
    assert await claim_task_dispatch(db_session, task_id) is True

    # Live duplicates (task already running) raise.
    task.status = "in_progress"
    await db_session.commit()
    with pytest.raises(RuntimeError, match="in_progress"):
        await claim_task_dispatch(db_session, task_id)

    # Terminal tasks are skipped.
    task.status = "completed"
    await db_session.commit()
    assert await claim_task_dispatch(db_session, task_id) is False


@pytest.mark.integration
async def test_advisory_episode_lock_across_engines(
    db_session, seeded_user, integration_engine
):
    """Two managers on separate connections fence each other via pg_locks."""
    from app.core.advisory_lock import string_lock_key

    holder = TranscriptionStateManager(engine=integration_engine)
    contender = TranscriptionStateManager(engine=integration_engine)

    episode_id = 4242

    assert await holder.acquire_task_lock(episode_id, task_id=1)
    # Re-entrant for the same task.
    assert await holder.acquire_task_lock(episode_id, task_id=1)
    assert await holder.is_episode_locked(episode_id) == 1

    # Another process cannot take or see the owner id.
    assert await contender.acquire_task_lock(episode_id, task_id=2) is False
    assert await contender.is_episode_locked(episode_id) == UNKNOWN_OWNER_TASK_ID

    # Release by the wrong task is refused.
    assert await contender.release_task_lock(episode_id, task_id=2) is False

    assert await holder.release_task_lock(episode_id, task_id=1)
    assert await contender.is_episode_locked(episode_id) is None

    # Sanity: the lock key namespace is distinct per episode.
    assert string_lock_key("transcription:episode:1") != string_lock_key(
        "transcription:episode:2"
    )


@pytest.mark.integration
async def test_feed_count_ttl_cache_roundtrip(db_session, seeded_user):
    repo = PodcastRepository(db_session)
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
    # The in-process TTL cache now holds the count for this user.
    assert seeded_user in feed_count_cache

    # A cached entry with a future expiry short-circuits the query.
    import time as time_module

    expires_at, _value = feed_count_cache[seeded_user]
    feed_count_cache[seeded_user] = (time_module.monotonic() + 60, 999)
    _, total3, _, _ = await repo.get_feed_lightweight_cursor_paginated(
        seeded_user, size=1
    )
    assert total3 == 999
    feed_count_cache[seeded_user] = (expires_at, 2)


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
