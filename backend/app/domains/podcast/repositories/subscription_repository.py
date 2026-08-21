"""Subscription aggregate: user subscriptions CRUD and metadata."""

from __future__ import annotations

import logging
from datetime import UTC, datetime

from sqlalchemy import and_, func, select
from sqlalchemy.orm import attributes

from app.core.datetime_utils import (
    ensure_timezone_aware_fetch_time,
)
from app.domains.podcast.models import (
    PodcastEpisode,
)
from app.domains.podcast.repositories.base import (
    BasePodcastRepository,
    _get_subscription_models,
)
from app.shared.repository_helpers import resolve_window_total


logger = logging.getLogger(__name__)


class PodcastSubscriptionRepository(BasePodcastRepository):
    """Subscription aggregate: user subscriptions CRUD and metadata."""

    async def create_or_update_subscription(
        self,
        user_id: int,
        feed_url: str,
        title: str,
        description: str = "",
        custom_name: str | None = None,
        metadata: dict | None = None,
        *,
        commit: bool = True,
    ):
        """Create or update a podcast subscription.

        Uses lazy imports to maintain domain boundary separation.
        """
        from app.domains.podcast.models import UpdateFrequency

        Subscription, UserSubscription = _get_subscription_models()

        stmt = select(Subscription).where(
            and_(
                Subscription.source_url == feed_url,
                Subscription.source_type == "podcast-rss",
            ),
        )
        result = await self.db.execute(stmt)
        subscription = result.scalar_one_or_none()

        update_frequency = UpdateFrequency.HOURLY.value
        update_time = None
        update_day_of_week = None

        setting = await self.settings_provider.get_setting(
            self.db, "rss.frequency_settings"
        )
        if setting:
            update_frequency = setting.get(
                "update_frequency",
                UpdateFrequency.HOURLY.value,
            )
            update_time = setting.get("update_time")
            update_day_of_week = setting.get("update_day_of_week")

        if subscription:
            user_sub_stmt = select(UserSubscription).where(
                and_(
                    UserSubscription.user_id == user_id,
                    UserSubscription.subscription_id == subscription.id,
                ),
            )
            user_sub_result = await self.db.execute(user_sub_stmt)
            user_sub = user_sub_result.scalar_one_or_none()

            if not user_sub:
                user_sub = UserSubscription(
                    user_id=user_id,
                    subscription_id=subscription.id,
                    update_frequency=update_frequency,
                    update_time=update_time,
                    update_day_of_week=update_day_of_week,
                )
                self.db.add(user_sub)
            elif user_sub.is_archived:
                user_sub.is_archived = False

            subscription.title = custom_name or title
            subscription.description = description
            subscription.updated_at = datetime.now(UTC)
            if metadata:
                if "image_url" in metadata:
                    subscription.image_url = metadata.get("image_url")
                existing_config = dict(subscription.config or {})
                existing_config.update(metadata)
                subscription.config = existing_config
                attributes.flag_modified(subscription, "config")
        else:
            subscription = Subscription(
                source_url=feed_url,
                source_type="podcast-rss",
                title=custom_name or title,
                description=description,
                status="active",
                fetch_interval=3600,
                image_url=(metadata or {}).get("image_url"),
                config=metadata or {},
            )
            self.db.add(subscription)
            await self.db.flush()

            user_sub = UserSubscription(
                user_id=user_id,
                subscription_id=subscription.id,
                update_frequency=update_frequency,
                update_time=update_time,
                update_day_of_week=update_day_of_week,
            )
            self.db.add(user_sub)

        if commit:
            await self.db.commit()
        else:
            await self.db.flush()
        # No refresh needed - subscription is already in session with updated values
        return subscription

    async def get_user_subscriptions(self, user_id: int) -> list:
        """Get all user subscriptions for podcasts.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        stmt = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    self._podcast_source_type_filter(),
                ),
            )
            .order_by(Subscription.created_at.desc())
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_subscription_by_id(
        self,
        user_id: int,
        sub_id: int,
    ):
        """Get a subscription by ID.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        stmt = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    Subscription.id == sub_id,
                    self._podcast_source_type_filter(),
                ),
            )
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_subscription_by_url(
        self,
        user_id: int,
        feed_url: str,
    ):
        """Get a subscription by URL.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        stmt = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    Subscription.source_url == feed_url,
                    self._podcast_source_type_filter(),
                ),
            )
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_subscription_by_id_direct(
        self,
        subscription_id: int,
    ):
        """Get a subscription by ID without user filter.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, _ = _get_subscription_models()

        stmt = select(Subscription).where(
            and_(
                Subscription.id == subscription_id,
                Subscription.source_type.in_(["podcast-rss", "rss"]),
            ),
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_user_subscriptions_paginated(
        self,
        user_id: int,
        page: int = 1,
        size: int = 20,
        filters: dict | None = None,
    ) -> tuple[list, int, dict[int, int]]:
        """Get paginated user subscriptions.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        skip = (page - 1) * size
        base_query = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    self._podcast_source_type_filter(),
                ),
            )
        )

        if filters and filters.status:
            base_query = base_query.where(Subscription.status == filters.status)

        episode_count_subquery = (
            select(
                PodcastEpisode.subscription_id.label("subscription_id"),
                func.count(PodcastEpisode.id).label("episode_count"),
            )
            .group_by(PodcastEpisode.subscription_id)
            .subquery()
        )

        query = (
            base_query.outerjoin(
                episode_count_subquery,
                episode_count_subquery.c.subscription_id == Subscription.id,
            )
            .add_columns(
                func.coalesce(episode_count_subquery.c.episode_count, 0),
                func.count(Subscription.id).over(),
            )
            .order_by(Subscription.created_at.desc(), Subscription.id.desc())
            .offset(skip)
            .limit(size)
        )

        result = await self.db.execute(query)
        rows = result.all()
        total = await resolve_window_total(
            self.db,
            rows,
            total_index=2,
            fallback_count_query=select(func.count()).select_from(
                base_query.subquery(),
            ),
        )
        subscriptions = [row[0] for row in rows]
        episode_counts = {row[0].id: int(row[1]) for row in rows}
        return subscriptions, total, episode_counts

    async def update_subscription_fetch_time(
        self,
        subscription_id: int,
        fetch_time: datetime | None = None,
    ):
        Subscription, _ = _get_subscription_models()
        stmt = select(Subscription).where(Subscription.id == subscription_id)
        result = await self.db.execute(stmt)
        subscription = result.scalar_one_or_none()

        if subscription:
            time_to_set = ensure_timezone_aware_fetch_time(
                fetch_time or datetime.now(UTC),
            )
            subscription.last_fetched_at = time_to_set
            await self.db.commit()

    async def update_subscription_metadata(self, subscription_id: int, metadata: dict):
        from sqlalchemy.orm import attributes

        Subscription, _ = _get_subscription_models()
        stmt = select(Subscription).where(Subscription.id == subscription_id)
        result = await self.db.execute(stmt)
        subscription = result.scalar_one_or_none()

        if subscription:
            current_config = dict(subscription.config or {})
            current_config.update(metadata)
            subscription.config = current_config
            attributes.flag_modified(subscription, "config")
            subscription.updated_at = datetime.now(UTC)
            await self.db.commit()
