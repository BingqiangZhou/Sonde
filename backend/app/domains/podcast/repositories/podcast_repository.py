"""Unified podcast repository - episodes, subscriptions, search, stats."""

from __future__ import annotations

import logging
from collections.abc import Mapping
from datetime import UTC, datetime
from inspect import isawaitable
from typing import TYPE_CHECKING, Any

from sqlalchemy import and_, case, desc, func, or_, select
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import attributes, joinedload

from app.admin.settings_provider import DatabaseSettingsProvider
from app.core.datetime_utils import (
    ensure_timezone_aware_fetch_time,
    sanitize_published_date,
)
from app.core.redis import RedisCache, get_shared_redis
from app.domains.podcast.models import (
    EpisodeHighlight,
    PodcastEpisode,
)
from app.shared.repository_helpers import resolve_window_total


if TYPE_CHECKING:
    pass


def _get_subscription_models():
    """Lazy import subscription models to maintain domain boundaries.

    This function is called at runtime when the models are actually needed
    for SQLAlchemy queries, but the TYPE_CHECKING guard above ensures they
    are not imported during type checking.

    Returns:
        Tuple of (Subscription, UserSubscription) models
    """
    from app.domains.podcast.models import Subscription, UserSubscription

    return Subscription, UserSubscription


if TYPE_CHECKING:
    pass

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)


def _get_user_subscription_model():
    """Lazy import UserSubscription model to maintain domain boundaries.

    Returns:
        UserSubscription model class
    """
    from app.domains.podcast.models import UserSubscription

    return UserSubscription


class PodcastRepository:
    """Unified podcast data access."""

    """Small shared base for specialized podcast repositories."""

    def __init__(
        self,
        db: AsyncSession,
        redis: RedisCache | None = None,
        settings_provider: DatabaseSettingsProvider | None = None,
    ):
        self.db = db
        self.redis = redis or get_shared_redis()
        self.settings_provider = settings_provider or DatabaseSettingsProvider()

    @staticmethod
    def _active_user_subscription_filters(user_id: int) -> tuple[Any, Any]:
        """Common filter for active user-subscription mappings.

        Uses lazy import to maintain domain boundary separation.
        """
        _, UserSubscription = _get_subscription_models()
        return (
            UserSubscription.user_id == user_id,
            UserSubscription.is_archived.is_(False),
        )

    @staticmethod
    def _podcast_source_type_filter() -> Any:
        """Filter for podcast source types.

        Uses lazy import to maintain domain boundary separation.
        """
        Subscription, _ = _get_subscription_models()
        return Subscription.source_type.in_(["podcast-rss", "rss"])

    """Subscription upsert, episode upsert, and summary state."""

    async def create_or_update_subscription(
        self,
        user_id: int,
        feed_url: str,
        title: str,
        description: str = "",
        custom_name: str | None = None,
        metadata: dict | None = None,
        tier: str = "T2",
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
                tier=tier,
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

        await self.db.commit()
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

    async def create_or_update_episode(
        self,
        subscription_id: int,
        title: str,
        description: str,
        audio_url: str,
        published_at: datetime,
        audio_duration: int | None = None,
        transcript_url: str | None = None,
        item_link: str | None = None,
        metadata: dict | None = None,
    ) -> tuple[PodcastEpisode, bool]:
        stmt = select(PodcastEpisode).where(PodcastEpisode.item_link == item_link)
        result = await self.db.execute(stmt)
        episode = result.scalar_one_or_none()

        if episode:
            episode.title = title
            episode.description = description
            episode.audio_url = audio_url
            episode.published_at = sanitize_published_date(published_at)
            episode.audio_duration = audio_duration
            episode.transcript_url = transcript_url
            episode.updated_at = datetime.now(UTC)
            if episode.subscription_id != subscription_id:
                episode.subscription_id = subscription_id
            if metadata:
                current_metadata = episode.metadata_json or {}
                episode.metadata_json = {**current_metadata, **metadata}
            is_new = False
        else:
            episode = PodcastEpisode(
                subscription_id=subscription_id,
                title=title,
                description=description,
                audio_url=audio_url,
                published_at=sanitize_published_date(published_at),
                audio_duration=audio_duration,
                transcript_url=transcript_url,
                item_link=item_link,
                status="pending_summary",
                metadata_json=metadata or {},
            )
            self.db.add(episode)
            is_new = True

        await self.db.commit()
        # episode.id auto-populated by SQLAlchemy after flush/commit
        return episode, is_new

    async def create_or_update_episodes_batch(
        self,
        subscription_id: int,
        episodes_data: list[dict[str, Any]],
    ) -> tuple[list[PodcastEpisode], list[PodcastEpisode]]:
        if not episodes_data:
            return [], []

        item_links = list(
            {data["item_link"] for data in episodes_data if data.get("item_link")},
        )
        existing_by_item_link: dict[str, PodcastEpisode] = {}

        if item_links:
            existing_stmt = select(PodcastEpisode).where(
                PodcastEpisode.item_link.in_(item_links),
            )
            existing_result = await self.db.execute(existing_stmt)
            existing_episodes = list(existing_result.scalars().all())
            existing_by_item_link = {
                episode.item_link: episode
                for episode in existing_episodes
                if episode.item_link
            }

        processed_episodes: list[PodcastEpisode] = []
        new_episodes: list[PodcastEpisode] = []
        now = datetime.now(UTC)

        for data in episodes_data:
            title = data.get("title") or "Untitled"
            description = data.get("description") or ""
            audio_url = data.get("audio_url") or ""
            transcript_url = data.get("transcript_url")
            audio_duration = data.get("audio_duration")
            item_link = data.get("item_link")
            metadata = data.get("metadata") or {}
            published_at_raw = data.get("published_at") or now
            published_at = sanitize_published_date(published_at_raw)

            episode = existing_by_item_link.get(item_link) if item_link else None
            if episode:
                episode.title = title
                episode.description = description
                episode.audio_url = audio_url
                episode.published_at = published_at
                episode.audio_duration = audio_duration
                episode.transcript_url = transcript_url
                episode.updated_at = now
                if episode.subscription_id != subscription_id:
                    episode.subscription_id = subscription_id
                if metadata:
                    current_metadata = episode.metadata_json or {}
                    episode.metadata_json = {**current_metadata, **metadata}
                processed_episodes.append(episode)
                continue

            new_episode = PodcastEpisode(
                subscription_id=subscription_id,
                title=title,
                description=description,
                audio_url=audio_url,
                published_at=published_at,
                audio_duration=audio_duration,
                transcript_url=transcript_url,
                item_link=item_link,
                status="pending_summary",
                metadata_json=metadata,
            )
            self.db.add(new_episode)
            processed_episodes.append(new_episode)
            new_episodes.append(new_episode)

        await self.db.flush()
        await self.db.commit()

        return processed_episodes, new_episodes

    async def get_unsummarized_episodes(
        self,
        subscription_id: int | None = None,
        limit: int | None = 100,
    ) -> list[PodcastEpisode]:
        stmt = select(PodcastEpisode).where(
            and_(
                PodcastEpisode.ai_summary.is_(None),
                PodcastEpisode.status.in_(["pending_summary", "summary_failed"]),
            ),
        )
        if subscription_id:
            stmt = stmt.where(PodcastEpisode.subscription_id == subscription_id)

        stmt = stmt.order_by(PodcastEpisode.published_at.desc())
        if limit and limit > 0:
            stmt = stmt.limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_pending_summaries_for_user(
        self,
        user_id: int,
    ) -> list[dict[str, Any]]:
        """Get pending summaries for a user.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        stmt = (
            select(PodcastEpisode, Subscription.title)
            .options(joinedload(PodcastEpisode.transcript))
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    self._podcast_source_type_filter(),
                    PodcastEpisode.ai_summary.is_(None),
                    PodcastEpisode.status.in_(["pending_summary", "summary_failed"]),
                ),
            )
            .order_by(PodcastEpisode.published_at.desc(), PodcastEpisode.id.desc())
        )
        rows = (await self.db.execute(stmt)).unique().all()
        results: list[dict[str, Any]] = []
        for episode, subscription_title in rows:
            description = episode.description or ""
            transcript = (
                episode.transcript.transcript_content if episode.transcript else ""
            )
            results.append(
                {
                    "episode_id": episode.id,
                    "subscription_title": subscription_title,
                    "episode_title": episode.title,
                    "size_estimate": len(description) + len(transcript),
                },
            )
        return results

    async def get_subscription_episodes(
        self,
        subscription_id: int,
        limit: int = 20,
    ) -> list[PodcastEpisode]:
        stmt = (
            select(PodcastEpisode)
            .options(joinedload(PodcastEpisode.subscription))
            .where(PodcastEpisode.subscription_id == subscription_id)
            .order_by(desc(PodcastEpisode.published_at))
            .limit(limit)
        )

        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def count_subscription_episodes(self, subscription_id: int) -> int:
        stmt = select(func.count(PodcastEpisode.id)).where(
            PodcastEpisode.subscription_id == subscription_id,
        )
        result = await self.db.execute(stmt)
        return result.scalar() or 0

    async def get_current_analyses(self, episode_ids: list[int]) -> dict[int, Any]:
        """当前 AI 判定映射（Phase E：feed/详情叠加评分字段）。"""
        if not episode_ids:
            return {}
        from sqlalchemy import select as _select

        from app.domains.insight.models import AiAnalysis

        rows = (
            (
                await self.db.execute(
                    _select(AiAnalysis).where(
                        AiAnalysis.episode_id.in_(episode_ids),
                        AiAnalysis.is_current.is_(True),
                    )
                )
            )
            .scalars()
            .all()
        )
        return {a.episode_id: a for a in rows}

    async def get_episode_by_id(
        self,
        episode_id: int,
        user_id: int | None = None,
    ) -> PodcastEpisode | None:
        """Get an episode by ID.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        stmt = (
            select(PodcastEpisode)
            .options(
                joinedload(PodcastEpisode.subscription),
                joinedload(PodcastEpisode.transcript),
            )
            .where(PodcastEpisode.id == episode_id)
        )
        if user_id:
            stmt = (
                stmt.join(Subscription)
                .join(
                    UserSubscription,
                    UserSubscription.subscription_id == Subscription.id,
                )
                .where(and_(*self._active_user_subscription_filters(user_id)))
            )

        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_episode_by_item_link(
        self,
        subscription_id: int,
        item_link: str,
    ) -> PodcastEpisode | None:
        stmt = select(PodcastEpisode).where(
            and_(
                PodcastEpisode.subscription_id == subscription_id,
                PodcastEpisode.item_link == item_link,
            ),
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def update_ai_summary(
        self,
        episode_id: int,
        summary: str,
        version: str = "v1",
        confidence: float | None = None,
        transcript_used: bool = False,
    ) -> PodcastEpisode:
        episode = await self.get_episode_by_id(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        episode.ai_summary = summary
        episode.summary_version = version
        episode.status = "summarized"
        if confidence:
            episode.ai_confidence_score = confidence

        metadata = episode.metadata_json or {}
        metadata["transcript_used"] = transcript_used
        metadata["summarized_at"] = datetime.now(UTC).isoformat()
        metadata.pop("summary_error", None)
        metadata.pop("summary_failed_at", None)
        episode.metadata_json = metadata

        await self.db.commit()
        # No refresh needed - episode is already in session with updated values
        await self.redis.set_ai_summary(episode_id, summary, version)
        return episode

    async def mark_summary_failed(self, episode_id: int, error: str) -> None:
        episode = await self.get_episode_by_id(episode_id)
        if episode:
            episode.status = "summary_failed"
            metadata = episode.metadata_json or {}
            metadata["summary_error"] = error
            metadata["failed_at"] = datetime.now(UTC).isoformat()
            episode.metadata_json = metadata
            await self.db.commit()

    """Subscription/episode pagination and lightweight feed queries."""

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

    async def get_episodes_paginated(
        self,
        user_id: int,
        page: int = 1,
        size: int = 20,
        filters: dict | None = None,
    ) -> tuple[list[PodcastEpisode], int]:
        """Get paginated episodes.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        skip = (page - 1) * size
        base_query = (
            select(PodcastEpisode)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(
                joinedload(PodcastEpisode.subscription),
                joinedload(PodcastEpisode.transcript),
            )
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )

        if filters:
            if filters.subscription_id:
                base_query = base_query.where(
                    PodcastEpisode.subscription_id == filters.subscription_id,
                )
            if filters.has_summary is not None:
                if filters.has_summary:
                    base_query = base_query.where(PodcastEpisode.ai_summary.isnot(None))
                else:
                    base_query = base_query.where(PodcastEpisode.ai_summary.is_(None))

        total_result = await self.db.execute(
            select(func.count()).select_from(base_query.subquery()),
        )
        total = int(total_result.scalar() or 0)

        query = (
            base_query.order_by(
                PodcastEpisode.published_at.desc(),
                PodcastEpisode.id.desc(),
            )
            .offset(skip)
            .limit(size)
        )

        result = await self.db.execute(query)
        rows = list(result.unique().scalars().all())
        return rows, total

    @staticmethod
    def _feed_count_cache_key(user_id: int) -> str:
        return f"podcast:feed:count:{user_id}"

    async def _get_feed_total_count(self, user_id: int) -> int:
        cache_key = self._feed_count_cache_key(user_id)
        cached_total = await self.redis.get(cache_key)
        if cached_total is not None:
            try:
                return int(cached_total)
            except (TypeError, ValueError):
                logger.warning("Invalid cached feed total count for user %s", user_id)

        Subscription, UserSubscription = _get_subscription_models()
        count_query = (
            select(func.count(PodcastEpisode.id))
            .select_from(PodcastEpisode)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )
        total_result = await self.db.execute(count_query)
        total = int(total_result.scalar() or 0)
        await self.redis.set(cache_key, str(total), ttl=120)
        return total

    def _build_feed_lightweight_base_query(self, user_id: int):
        """Build base query for lightweight feed.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        return (
            select(
                PodcastEpisode.id.label("id"),
                PodcastEpisode.subscription_id.label("subscription_id"),
                Subscription.title.label("subscription_title"),
                Subscription.image_url.label("subscription_image_url"),
                Subscription.config.label("subscription_config"),
                PodcastEpisode.title.label("title"),
                PodcastEpisode.description.label("description"),
                PodcastEpisode.ai_summary.label("ai_summary"),
                PodcastEpisode.audio_url.label("audio_url"),
                PodcastEpisode.audio_duration.label("audio_duration"),
                PodcastEpisode.audio_file_size.label("audio_file_size"),
                PodcastEpisode.published_at.label("published_at"),
                PodcastEpisode.image_url.label("image_url"),
                PodcastEpisode.item_link.label("item_link"),
                PodcastEpisode.transcript_url.label("transcript_url"),
                PodcastEpisode.summary_version.label("summary_version"),
                PodcastEpisode.ai_confidence_score.label("ai_confidence_score"),
                PodcastEpisode.season.label("season"),
                PodcastEpisode.episode_number.label("episode_number"),
                PodcastEpisode.explicit.label("explicit"),
                PodcastEpisode.status.label("status"),
                PodcastEpisode.metadata_json.label("metadata"),
                PodcastEpisode.created_at.label("created_at"),
                PodcastEpisode.updated_at.label("updated_at"),
            )
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )

    def _build_feed_lightweight_item(self, row: Mapping[str, Any]) -> dict[str, Any]:
        row_data = dict(row)
        subscription_config = row_data.pop("subscription_config", None)
        subscription_image_url = self._normalize_optional_image_url(
            row_data.get("subscription_image_url"),
        )
        config_image_url = None
        if isinstance(subscription_config, dict):
            config_image_url = self._normalize_optional_image_url(
                subscription_config.get("image_url"),
            )
        effective_subscription_image = config_image_url or subscription_image_url

        image_url = self._normalize_optional_image_url(row_data.get("image_url"))
        if image_url is None:
            image_url = effective_subscription_image

        return {
            "id": row_data["id"],
            "subscription_id": row_data["subscription_id"],
            "subscription_title": row_data.get("subscription_title"),
            "subscription_image_url": effective_subscription_image,
            "title": row_data["title"],
            "description": row_data.get("description"),
            "audio_url": row_data["audio_url"],
            "audio_duration": row_data.get("audio_duration"),
            "audio_file_size": row_data.get("audio_file_size"),
            "published_at": row_data["published_at"],
            "image_url": image_url,
            "item_link": row_data.get("item_link"),
            "transcript_url": row_data.get("transcript_url"),
            "transcript_content": None,
            "ai_summary": row_data.get("ai_summary"),
            "summary_version": row_data.get("summary_version"),
            "ai_confidence_score": row_data.get("ai_confidence_score"),
            "season": row_data.get("season"),
            "episode_number": row_data.get("episode_number"),
            "explicit": bool(row_data.get("explicit", False)),
            "status": row_data.get("status") or "published",
            "metadata": row_data.get("metadata") or {},
            "created_at": row_data["created_at"],
            "updated_at": row_data.get("updated_at"),
        }

    async def get_feed_lightweight_page_paginated(
        self,
        user_id: int,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict[str, Any]], int]:
        total = await self._get_feed_total_count(user_id)
        query = self._build_feed_lightweight_base_query(user_id).order_by(
            desc(PodcastEpisode.published_at),
            desc(PodcastEpisode.id),
        )
        query = query.offset((page - 1) * size).limit(size)

        result = await self.db.execute(query)
        rows = result.mappings().all()
        items = [self._build_feed_lightweight_item(row) for row in rows]
        return items, total

    async def get_feed_lightweight_cursor_paginated(
        self,
        user_id: int,
        size: int = 20,
        cursor_published_at: Any = None,
        cursor_episode_id: int | None = None,
    ) -> tuple[list[dict[str, Any]], int, bool, tuple[Any, int] | None]:
        total = await self._get_feed_total_count(user_id)
        query = self._build_feed_lightweight_base_query(user_id)

        if cursor_published_at is not None and cursor_episode_id is not None:
            query = query.where(
                or_(
                    PodcastEpisode.published_at < cursor_published_at,
                    and_(
                        PodcastEpisode.published_at == cursor_published_at,
                        PodcastEpisode.id < cursor_episode_id,
                    ),
                ),
            )

        query = query.order_by(
            desc(PodcastEpisode.published_at),
            desc(PodcastEpisode.id),
        ).limit(size + 1)

        result = await self.db.execute(query)
        rows = result.mappings().all()

        has_more = len(rows) > size
        trimmed_rows = rows[:size]
        items = [self._build_feed_lightweight_item(row) for row in trimmed_rows]
        next_cursor_values: tuple[Any, int] | None = None
        if has_more and trimmed_rows:
            tail = trimmed_rows[-1]
            next_cursor_values = (tail["published_at"], tail["id"])

        return items, total, has_more, next_cursor_values

    async def get_feed_cursor_paginated(
        self,
        user_id: int,
        size: int = 20,
        cursor_published_at: Any = None,
        cursor_episode_id: int | None = None,
    ) -> tuple[list[PodcastEpisode], int, bool, tuple[Any, int] | None]:
        """Get cursor-paginated feed.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        query = (
            select(PodcastEpisode)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(
                joinedload(PodcastEpisode.subscription),
                joinedload(PodcastEpisode.transcript),
            )
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )
        total = await self._get_feed_total_count(user_id)

        if cursor_published_at is not None and cursor_episode_id is not None:
            query = query.where(
                or_(
                    PodcastEpisode.published_at < cursor_published_at,
                    and_(
                        PodcastEpisode.published_at == cursor_published_at,
                        PodcastEpisode.id < cursor_episode_id,
                    ),
                ),
            )

        query = query.order_by(
            desc(PodcastEpisode.published_at),
            desc(PodcastEpisode.id),
        ).limit(size + 1)

        result = await self.db.execute(query)
        rows = list(result.unique().scalars().all())

        has_more = len(rows) > size
        episodes = rows[:size]
        next_cursor_values: tuple[Any, int] | None = None
        if has_more and episodes:
            tail = episodes[-1]
            next_cursor_values = (tail.published_at, tail.id)

        return episodes, total, has_more, next_cursor_values

    @staticmethod
    def _normalize_optional_image_url(value: Any) -> str | None:
        if not isinstance(value, str):
            return None
        normalized = value.strip()
        return normalized or None

    """Search and aggregated stats."""

    async def search_episodes(
        self,
        user_id: int,
        query: str,
        search_in: str = "all",
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[PodcastEpisode], int]:
        keyword = query.strip()
        if not keyword:
            return [], 0

        like_pattern = f"%{keyword}%"
        bind: Any = None
        try:
            bind = self.db.get_bind()
            if isawaitable(bind):
                bind = await bind
        except Exception:
            bind = getattr(self.db, "bind", None)
        is_postgresql = bool(bind and bind.dialect.name == "postgresql")

        def _coalesced_text(column: Any) -> Any:
            return func.coalesce(column, "")

        def _build_text_match_condition(column: Any, enable_pg_trgm: bool) -> Any:
            coalesced = _coalesced_text(column)
            ilike_condition = coalesced.ilike(like_pattern)
            if not enable_pg_trgm:
                return ilike_condition
            return or_(coalesced.op("%")(keyword), ilike_condition)

        def _build_relevance_term(
            column: Any,
            weight: float,
            enable_pg_trgm: bool,
        ) -> Any:
            coalesced = _coalesced_text(column)
            if enable_pg_trgm:
                return func.similarity(coalesced, keyword) * weight
            return case((coalesced.ilike(like_pattern), weight), else_=0.0)

        async def _execute_search(
            enable_pg_trgm: bool,
        ) -> tuple[list[PodcastEpisode], int]:
            search_conditions: list[Any] = []
            relevance_terms: list[Any] = []

            if search_in in {"title", "all"}:
                search_conditions.append(
                    _build_text_match_condition(PodcastEpisode.title, enable_pg_trgm),
                )
                relevance_terms.append(
                    _build_relevance_term(PodcastEpisode.title, 1.0, enable_pg_trgm),
                )
            if search_in in {"description", "all"}:
                search_conditions.append(
                    _build_text_match_condition(
                        PodcastEpisode.description,
                        enable_pg_trgm,
                    ),
                )
                relevance_terms.append(
                    _build_relevance_term(
                        PodcastEpisode.description,
                        0.7,
                        enable_pg_trgm,
                    ),
                )
            if search_in in {"summary", "all"}:
                search_conditions.append(
                    _build_text_match_condition(
                        PodcastEpisode.ai_summary,
                        enable_pg_trgm,
                    ),
                )
                relevance_terms.append(
                    _build_relevance_term(
                        PodcastEpisode.ai_summary,
                        0.9,
                        enable_pg_trgm,
                    ),
                )

            if not search_conditions:
                search_conditions.append(
                    _build_text_match_condition(PodcastEpisode.title, enable_pg_trgm),
                )
                relevance_terms.append(
                    _build_relevance_term(PodcastEpisode.title, 1.0, enable_pg_trgm),
                )

            relevance_score = relevance_terms[0]
            for term in relevance_terms[1:]:
                relevance_score = relevance_score + term
            relevance_score = relevance_score.label("relevance_score")

            # Get models lazily to maintain domain boundaries
            Subscription, UserSubscription = _get_subscription_models()

            base_query = (
                select(PodcastEpisode, relevance_score)
                .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
                .join(
                    UserSubscription,
                    UserSubscription.subscription_id == Subscription.id,
                )
                .options(joinedload(PodcastEpisode.subscription))
                .where(
                    and_(
                        *self._active_user_subscription_filters(user_id),
                        or_(*search_conditions),
                    ),
                )
            )

            paged_query = (
                base_query.add_columns(
                    func.count(PodcastEpisode.id).over().label("total_count"),
                )
                .order_by(
                    desc(relevance_score),
                    desc(PodcastEpisode.published_at),
                    desc(PodcastEpisode.id),
                )
                .offset((page - 1) * size)
                .limit(size)
            )
            result = await self.db.execute(paged_query)
            rows = list(result.unique().all())
            if rows:
                total = int(rows[0][2] or 0)
            else:
                total = int(
                    await self.db.scalar(
                        select(func.count()).select_from(base_query.subquery()),
                    )
                    or 0,
                )

            episodes: list[PodcastEpisode] = []
            for episode, score, _ in rows:
                try:
                    episode.relevance_score = float(score or 0.0)
                except Exception:
                    episode.relevance_score = 0.0
                episodes.append(episode)
            return episodes, total

        if is_postgresql:
            try:
                async with self.db.begin_nested():
                    return await _execute_search(enable_pg_trgm=True)
            except DBAPIError as exc:
                message = str(getattr(exc, "orig", exc)).lower()
                pg_trgm_error = (
                    "similarity(" in message
                    or "operator does not exist" in message
                    or "pg_trgm" in message
                )
                if pg_trgm_error:
                    logger.warning(
                        "pg_trgm unavailable; fallback to ILIKE: %s",
                        exc,
                    )
                    return await _execute_search(enable_pg_trgm=False)
                raise
        return await _execute_search(enable_pg_trgm=False)

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

    def _subscription_count_stmt(self, user_id: int) -> Any:
        Subscription, UserSubscription = _get_subscription_models()
        return (
            select(func.count(Subscription.id))
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )

    def _episode_stats_stmt(self, user_id: int) -> Any:
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

        return select(*columns).select_from(
            PodcastEpisode.__table__.join(
                Subscription.__table__,
                PodcastEpisode.subscription_id == Subscription.id,
            ).join(
                UserSubscription.__table__,
                and_(
                    UserSubscription.subscription_id == Subscription.id,
                    *self._active_user_subscription_filters(user_id),
                ),
            ),
        )

    async def get_profile_stats_aggregated(self, user_id: int) -> dict[str, Any]:
        Subscription, UserSubscription = _get_subscription_models()
        total_subscriptions = (
            await self.db.scalar(self._subscription_count_stmt(user_id)) or 0
        )
        episode_stats_result = await self.db.execute(
            self._episode_stats_stmt(user_id),
        )
        episode_stats = episode_stats_result.one()

        # Count highlights from user's active subscriptions
        highlight_count_stmt = (
            select(func.count(EpisodeHighlight.id))
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(
                UserSubscription,
                Subscription.id == UserSubscription.subscription_id,
            )
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    EpisodeHighlight.status == "active",
                )
            )
        )
        highlight_count_result = await self.db.execute(highlight_count_stmt)
        total_highlights = highlight_count_result.scalar() or 0

        return {
            "total_subscriptions": total_subscriptions,
            "total_episodes": episode_stats.total_episodes or 0,
            "summaries_generated": episode_stats.summaries_generated or 0,
            "pending_summaries": episode_stats.pending_summaries or 0,
            "total_highlights": total_highlights,
        }

    async def get_subscription_episodes_batch(
        self,
        subscription_ids: list[int],
        limit_per_subscription: int = 3,
    ) -> dict[int, list[PodcastEpisode]]:
        if not subscription_ids:
            return {}

        ranked_subquery = (
            select(
                PodcastEpisode.id.label("episode_id"),
                func.row_number()
                .over(
                    partition_by=PodcastEpisode.subscription_id,
                    order_by=(
                        PodcastEpisode.published_at.desc(),
                        PodcastEpisode.id.desc(),
                    ),
                )
                .label("row_number"),
            )
            .where(PodcastEpisode.subscription_id.in_(subscription_ids))
            .subquery()
        )

        stmt = (
            select(PodcastEpisode)
            .join(ranked_subquery, ranked_subquery.c.episode_id == PodcastEpisode.id)
            .where(ranked_subquery.c.row_number <= limit_per_subscription)
            .order_by(
                PodcastEpisode.subscription_id.asc(),
                PodcastEpisode.published_at.desc(),
                PodcastEpisode.id.desc(),
            )
        )

        result = await self.db.execute(stmt)
        rows = result.scalars().all()

        episodes_by_sub: dict[int, list[PodcastEpisode]] = {}
        for episode in rows:
            episodes_by_sub.setdefault(episode.subscription_id, []).append(episode)
        return episodes_by_sub


# Backward compatibility aliases
PodcastEpisodeRepository = PodcastRepository
PodcastSubscriptionRepository = PodcastRepository
PodcastSearchRepository = PodcastRepository
PodcastStatsRepository = PodcastRepository
