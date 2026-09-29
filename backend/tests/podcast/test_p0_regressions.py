"""P0 regression tests for the runtime breaks found in the 2026-08-21 audit.

Each test drives a real service/repository path (real sqlite session, no
AsyncMock'd internals) that previously crashed after the RedisCache
consolidation removed domain-specific cache methods.
"""

import hashlib
import hmac
from datetime import UTC, datetime
from unittest.mock import patch

import pytest

from app.domains.podcast.models import (
    PodcastEpisode,
    Subscription,
    UserSubscription,
)
from app.domains.podcast.repositories import PodcastRepository
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.transcription.state import claim_task_dispatch


async def _seed_subscription_with_episode(db_session) -> tuple[int, int]:
    """Create user + subscription + one episode; return (user_id, episode_id)."""
    from sqlalchemy import text

    await db_session.execute(
        text(
            "INSERT INTO users (email, username, hashed_password, created_at, updated_at) "
            "VALUES ('regression@example.com', 'regression_user', 'x', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
        )
    )
    await db_session.flush()
    user_id_row = await db_session.execute(
        text("SELECT id FROM users WHERE email = 'regression@example.com'")
    )
    user_id = user_id_row.scalar_one()

    subscription = Subscription(
        title="Regression Cast",
        source_type="podcast-rss",
        source_url="https://example.com/feed.xml",
    )
    db_session.add(subscription)
    await db_session.flush()

    db_session.add(UserSubscription(user_id=user_id, subscription_id=subscription.id))
    episode = PodcastEpisode(
        subscription_id=subscription.id,
        title="Episode 1",
        description="desc",
        audio_url="https://example.com/ep1.mp3",
        published_at=datetime.now(UTC),
        audio_duration=120,
        item_link="https://example.com/episodes/1",
    )
    db_session.add(episode)
    await db_session.commit()
    return user_id, episode.id


@pytest.mark.asyncio
async def test_list_episodes_by_subscription(db_session) -> None:
    """Regression: subscription-filtered listing crashed on redis.get_episode_list."""
    from types import SimpleNamespace

    user_id, episode_id = await _seed_subscription_with_episode(db_session)
    service = PodcastEpisodeService(db_session, user_id)

    filters = SimpleNamespace(subscription_id=1, has_summary=None, is_played=None)
    results, total = await service.list_episodes(filters=filters, page=1, size=10)

    assert total == 1
    assert [ep["id"] for ep in results] == [episode_id]


@pytest.mark.asyncio
async def test_get_episode_with_summary_direct_load(db_session) -> None:
    """Regression: episode detail crashed on redis.get_episode_detail."""
    user_id, episode_id = await _seed_subscription_with_episode(db_session)
    service = PodcastEpisodeService(db_session, user_id)

    result = await service.get_episode_with_summary(episode_id)

    assert result is not None
    assert result["id"] == episode_id
    assert result["title"] == "Episode 1"


@pytest.mark.asyncio
async def test_batch_upsert_new_episodes_completes(db_session) -> None:
    """Regression: feed ingest crashed caching new-episode metadata."""
    user_id, _ = await _seed_subscription_with_episode(db_session)
    repo = PodcastRepository(db_session)

    processed, new = await repo.create_or_update_episodes_batch(
        subscription_id=1,
        episodes_data=[
            {
                "title": "Fresh episode",
                "description": "desc",
                "audio_url": "https://example.com/ep2.mp3",
                "published_at": datetime.now(UTC),
                "audio_duration": 60,
                "transcript_url": None,
                "item_link": "https://example.com/episodes/2",
                "metadata": {},
            }
        ],
    )

    assert len(new) == 1
    assert new[0].title == "Fresh episode"
    assert new[0].status == "pending_summary"


@pytest.mark.asyncio
async def test_claim_task_dispatch_status_semantics(db_session) -> None:
    """The dispatch claim is decided by the task status row, not a guard key."""
    from app.domains.podcast.models import TranscriptionTask

    # Unknown task rows behave like pending: allowed to proceed.
    assert await claim_task_dispatch(db_session, task_id=1) is True

    _user_id, episode_id = await _seed_subscription_with_episode(db_session)
    task = TranscriptionTask(
        episode_id=episode_id,
        status="pending",
        current_step="not_started",
        original_audio_url="https://example.com/x.mp3",
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)

    assert await claim_task_dispatch(db_session, task.id) is True

    task.status = "in_progress"
    await db_session.commit()
    with pytest.raises(RuntimeError, match="in_progress"):
        await claim_task_dispatch(db_session, task.id)

    task.status = "completed"
    await db_session.commit()
    assert await claim_task_dispatch(db_session, task.id) is False


def test_admin_session_hash_resolves_secret_key_lazily() -> None:
    """Regression: admin login crashed with NoneType.encode when SECRET_KEY unset."""
    from app.admin.auth import _compute_session_hash

    with patch("app.admin.auth.get_settings") as mock_settings:
        settings = mock_settings.return_value
        settings.SECRET_KEY = None
        settings.get_secret_key.return_value = "generated-secret"

        session_hash = _compute_session_hash("admin-key")

    expected = hmac.new(b"generated-secret", b"admin-key", hashlib.sha256).hexdigest()
    assert session_hash == expected
