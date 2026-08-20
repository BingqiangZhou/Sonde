"""Stats read model: aggregated profile and user statistics."""

from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import and_, case, func, select

from app.domains.podcast.models import (
    PodcastDailyReport,
    PodcastEpisode,
    PodcastPlaybackState,
)
from app.domains.podcast.repositories.base import (
    BasePodcastRepository,
    _get_subscription_models,
)


logger = logging.getLogger(__name__)

class StatsRepository(BasePodcastRepository):
    """Stats read model: aggregated profile and user statistics."""

    def _subscription_count_stmt(self, user_id: int) -> Any:
        Subscription, UserSubscription = _get_subscription_models()
        return (
            select(func.count(Subscription.id))
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )

    def _episode_stats_stmt(
        self,
        user_id: int,
        *,
        include_played_episodes: bool = False,
        include_total_playtime: bool = False,
    ) -> Any:
        Subscription, UserSubscription = _get_subscription_models()
        columns: list[Any] = [
            func.count(PodcastEpisode.id).label("total_episodes"),
            func.sum(case((PodcastEpisode.ai_summary.isnot(None), 1), else_=0)).label(
                "summaries_generated",
            ),
            func.sum(case((PodcastEpisode.ai_summary.is_(None), 1), else_=0)).label(
                "pending_summaries",
            ),
        ]

        if include_played_episodes:
            columns.append(
                func.count(func.distinct(PodcastPlaybackState.episode_id)).label(
                    "played_episodes",
                ),
            )
        if include_total_playtime:
            columns.append(
                func.coalesce(func.sum(PodcastPlaybackState.current_position), 0).label(
                    "total_playtime",
                ),
            )

        return select(*columns).select_from(
            PodcastEpisode.__table__.join(
                Subscription.__table__,
                PodcastEpisode.subscription_id == Subscription.id,
            )
            .join(
                UserSubscription.__table__,
                and_(
                    UserSubscription.subscription_id == Subscription.id,
                    *self._active_user_subscription_filters(user_id),
                ),
            )
            .outerjoin(
                PodcastPlaybackState.__table__,
                and_(
                    PodcastPlaybackState.episode_id == PodcastEpisode.id,
                    PodcastPlaybackState.user_id == user_id,
                ),
            ),
        )

    async def get_profile_stats_aggregated(self, user_id: int) -> dict[str, Any]:
        total_subscriptions = (
            await self.db.scalar(self._subscription_count_stmt(user_id)) or 0
        )
        episode_stats_result = await self.db.execute(
            self._episode_stats_stmt(user_id, include_played_episodes=True),
        )
        episode_stats = episode_stats_result.one()

        latest_report_stmt = (
            select(PodcastDailyReport.report_date)
            .where(PodcastDailyReport.user_id == user_id)
            .order_by(PodcastDailyReport.report_date.desc())
            .limit(1)
        )
        latest_report_result = await self.db.execute(latest_report_stmt)
        latest_report_date = latest_report_result.scalar_one_or_none()

        return {
            "total_subscriptions": total_subscriptions,
            "total_episodes": episode_stats.total_episodes or 0,
            "summaries_generated": episode_stats.summaries_generated or 0,
            "pending_summaries": episode_stats.pending_summaries or 0,
            "played_episodes": episode_stats.played_episodes or 0,
            "latest_daily_report_date": latest_report_date.isoformat()
            if latest_report_date
            else None,
        }

    async def get_user_stats_aggregated(self, user_id: int) -> dict[str, Any]:
        Subscription, UserSubscription = _get_subscription_models()
        total_subscriptions = (
            await self.db.scalar(self._subscription_count_stmt(user_id)) or 0
        )
        episode_stats_result = await self.db.execute(
            self._episode_stats_stmt(user_id, include_total_playtime=True),
        )
        episode_stats = episode_stats_result.one()

        active_check_stmt = (
            select(func.count(Subscription.id))
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    Subscription.status == "active",
                ),
            )
        )
        active_check_result = await self.db.execute(active_check_stmt)
        has_active_plus = (active_check_result.scalar() or 0) > 0

        return {
            "total_subscriptions": total_subscriptions,
            "total_episodes": episode_stats.total_episodes or 0,
            "total_playtime": episode_stats.total_playtime or 0,
            "summaries_generated": episode_stats.summaries_generated or 0,
            "pending_summaries": episode_stats.pending_summaries or 0,
            "has_active_plus": has_active_plus,
        }
