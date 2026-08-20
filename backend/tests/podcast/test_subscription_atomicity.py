"""Aggregate-split and subscription-atomicity regression tests."""

import pytest
from sqlalchemy import func, select

from app.domains.podcast.models import PodcastEpisode, Subscription, UserSubscription
from app.domains.podcast.repositories.podcast_repository import PodcastRepository


_MISSING = object()


def _episode_payload(n: int, *, item_link: str | None | object = _MISSING) -> dict:
    if item_link is _MISSING:
        item_link = f"https://example.com/episodes/{n}"
    return {
        "title": f"Episode {n}",
        "description": "desc",
        "audio_url": f"https://example.com/ep{n}.mp3",
        "published_at": None,
        "audio_duration": 60,
        "transcript_url": None,
        "item_link": item_link,
        "metadata": {},
    }


@pytest.mark.asyncio
async def test_add_subscription_with_episodes_single_transaction(db_session) -> None:
    repo = PodcastRepository(db_session)

    subscription, processed, new = await repo.add_subscription_with_episodes(
        user_id=1,
        feed_url="https://example.com/feed.xml",
        title="Atomic Cast",
        description="desc",
        metadata={"platform": "generic"},
        episodes_data=[_episode_payload(1), _episode_payload(2)],
    )

    assert subscription.id is not None
    assert len(new) == 2
    sub_count = (
        await db_session.execute(select(func.count()).select_from(Subscription))
    ).scalar_one()
    episode_count = (
        await db_session.execute(select(func.count()).select_from(PodcastEpisode))
    ).scalar_one()
    assert sub_count >= 1
    assert episode_count == 2


@pytest.mark.asyncio
async def test_add_subscription_rolls_back_when_episodes_fail(db_session) -> None:
    repo = PodcastRepository(db_session)

    # item_link is NOT NULL — a None payload forces the episode insert to
    # fail after the subscription upsert succeeded.
    with pytest.raises(Exception, match="item_link"):
        await repo.add_subscription_with_episodes(
            user_id=1,
            feed_url="https://example.com/broken.xml",
            title="Broken Cast",
            description="desc",
            metadata={},
            episodes_data=[_episode_payload(1, item_link=None)],
        )

    await db_session.rollback()

    subs = (
        await db_session.execute(
            select(Subscription).where(Subscription.source_url == "https://example.com/broken.xml")
        )
    ).scalars().all()
    assert subs == [], "subscription must not persist when episode ingest fails"
    user_subs = (
        await db_session.execute(select(UserSubscription))
    ).scalars().all()
    assert user_subs == []
