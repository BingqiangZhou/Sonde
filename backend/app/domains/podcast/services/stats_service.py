"""Podcast stats service.

Provides aggregated knowledge-library stats (subscriptions/episodes/summaries/highlights).
Queries are served live from the database; freshness is handled by the client
(profile stats are re-fetched after subscription/favorite mutations).
"""

import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.podcast.repositories import PodcastStatsRepository


logger = logging.getLogger(__name__)


class PodcastStatsService:
    """Service for user podcast statistics."""

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        repo: PodcastStatsRepository | None = None,
    ):
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastStatsRepository(db)

    async def get_profile_stats(self) -> dict[str, Any]:
        """Get lightweight profile stats for profile page cards."""
        return await self.repo.get_profile_stats_aggregated(self.user_id)
