"""Podcast stats service.

Provides aggregated knowledge-library stats (subscriptions/episodes/summaries/highlights)
and cache handling.
"""

import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import (
    RedisCache,
    get_shared_redis,
)
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
        redis: RedisCache | None = None,
    ):
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastStatsRepository(db)
        self.redis = redis or get_shared_redis()

    async def get_profile_stats(self) -> dict[str, Any]:
        """Get lightweight profile stats for profile page cards."""
        logger.info("Cache MISS for profile stats: user_id=%s", self.user_id)
        result = await self.repo.get_profile_stats_aggregated(self.user_id)

        return result

    async def invalidate_cached_stats(self) -> None:
        """Invalidate user stats/profile stats caches in parallel."""
        try:
            await self.redis.delete(f"podcast:stats:{self.user_id}")
        except Exception as e:
            logger.warning(
                f"Redis user stats cache invalidation failed for user_id={self.user_id}: {e}"
            )
        try:
            await self.redis.delete(f"podcast:stats:profile:{self.user_id}")
        except Exception as e:
            logger.warning(
                f"Redis profile stats cache invalidation failed for user_id={self.user_id}: {e}"
            )
