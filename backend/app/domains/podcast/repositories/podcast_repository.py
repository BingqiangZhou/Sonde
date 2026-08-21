"""Composed podcast repository: all aggregate repositories in one object.

Services that legitimately cross aggregates (summary writes read
episodes) depend on this facade; the aggregate classes in this package
are the organizational units and can be used standalone where their
method group is self-contained.
"""

from __future__ import annotations

from typing import Any

from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.repositories.episode_repository import EpisodeRepository
from app.domains.podcast.repositories.feed_repository import FeedQueryRepository
from app.domains.podcast.repositories.subscription_repository import (
    PodcastSubscriptionRepository,
)
from app.domains.podcast.repositories.summary_repository import SummaryRepository


class PodcastRepository(
    PodcastSubscriptionRepository,
    EpisodeRepository,
    FeedQueryRepository,
    SummaryRepository,
):
    """Unified podcast data access (composition of all aggregate repositories)."""

    async def add_subscription_with_episodes(
        self,
        user_id: int,
        feed_url: str,
        title: str,
        description: str,
        metadata: dict | None,
        episodes_data: list[dict[str, Any]],
    ) -> tuple[Any, list[PodcastEpisode], list[PodcastEpisode]]:
        """Create the subscription and its episodes in ONE transaction.

        The per-aggregate upserts each commit by default; here they only
        flush so a failure between subscription and episode inserts cannot
        leave a subscription without its episodes.
        """
        subscription = await self.create_or_update_subscription(
            user_id,
            feed_url,
            title,
            description,
            None,  # custom_name
            metadata=metadata,
            commit=False,
        )
        processed, new_episodes = await self.create_or_update_episodes_batch(
            subscription_id=subscription.id,
            episodes_data=episodes_data,
            commit=False,
        )
        await self.db.commit()
        return subscription, processed, new_episodes
