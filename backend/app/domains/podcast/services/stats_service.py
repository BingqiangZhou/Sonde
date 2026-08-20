"""Podcast stats service.

Provides aggregated user-level podcast stats.
"""

import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.podcast.repositories import PodcastRepository
from app.domains.podcast.services.playback_service import PodcastPlaybackService


logger = logging.getLogger(__name__)


class PodcastStatsService:
    """Service for user podcast statistics."""

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        repo: PodcastRepository | None = None,
        playback_service: PodcastPlaybackService | None = None,
    ):
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastRepository(db)
        self.playback_service = playback_service or PodcastPlaybackService(db, user_id)

    async def get_user_stats(self) -> dict[str, Any]:
        """Get aggregated user stats with playback context.

        Queries run sequentially: they share one AsyncSession, which does not
        allow concurrent operations.
        """
        try:
            stats = await self.repo.get_user_stats_aggregated(self.user_id)
        except Exception:
            logger.exception(
                "Failed to aggregate stats for user_id=%s, defaulting to empty",
                self.user_id,
            )
            stats = {}

        try:
            recently_played = await self.playback_service.get_recently_played(limit=5)
        except Exception:
            logger.warning(
                "Failed to get recently played for user_id=%s, defaulting to empty list",
                self.user_id,
            )
            recently_played = []

        try:
            listening_streak = await self.playback_service.calculate_listening_streak()
        except Exception:
            logger.warning(
                "Failed to calculate listening streak for user_id=%s, defaulting to 0",
                self.user_id,
            )
            listening_streak = 0

        return {
            **stats,
            "recently_played": recently_played,
            "top_categories": [],
            "listening_streak": listening_streak,
        }

    async def get_profile_stats(self) -> dict[str, Any]:
        """Get lightweight profile stats for profile page cards."""
        return await self.repo.get_profile_stats_aggregated(self.user_id)
