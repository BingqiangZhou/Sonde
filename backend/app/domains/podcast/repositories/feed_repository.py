"""Feed/history read models: lightweight projections and pagination."""

from __future__ import annotations

import logging
from collections.abc import Mapping
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import and_, desc, func, or_, select

from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.repositories.base import (
    BasePodcastRepository,
    _get_subscription_models,
)


logger = logging.getLogger(__name__)


def _as_utc(value: Any) -> Any:
    """Coerce naive cursor timestamps to UTC.

    asyncpg mis-encodes naive datetimes bound against timestamptz columns
    (microsecond truncation), silently breaking keyset boundaries. Cursor
    tokens carry naive ISO strings, so reattach UTC before querying.
    """
    if isinstance(value, datetime) and value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value


class FeedQueryRepository(BasePodcastRepository):
    """Feed/history read models: lightweight projections and pagination."""

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
                PodcastEpisode.ai_confidence_score.label("ai_confidence_score"),
                PodcastEpisode.play_count.label("play_count"),
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
            "ai_confidence_score": row_data.get("ai_confidence_score"),
            "play_count": row_data.get("play_count") or 0,
            "last_played_at": row_data.get("last_played_at"),
            "season": row_data.get("season"),
            "episode_number": row_data.get("episode_number"),
            "explicit": bool(row_data.get("explicit", False)),
            "status": row_data.get("status") or "published",
            "metadata": row_data.get("metadata") or {},
            # Playback state is client-side truth now; nulls here let the
            # app overlay its local positions without server conflicts.
            "playback_position": None,
            "is_playing": False,
            "playback_rate": 1.0,
            "is_played": False,
            "created_at": row_data["created_at"],
            "updated_at": row_data.get("updated_at"),
        }

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
            boundary = _as_utc(cursor_published_at)
            query = query.where(
                or_(
                    PodcastEpisode.published_at < boundary,
                    and_(
                        PodcastEpisode.published_at == boundary,
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

    async def get_feed_sync_paginated(
        self,
        user_id: int,
        size: int = 50,
        cursor_updated_at: Any = None,
        cursor_episode_id: int | None = None,
    ) -> tuple[list[dict[str, Any]], bool, tuple[Any, int] | None]:
        """Episodes changed since a keyset cursor, oldest-first.

        Client-cache hydration endpoint: unlike the feed query this walks
        ``updated_at`` ascending so a client can page from the beginning,
        persist the tail cursor as its sync watermark, and reuse it for
        later incremental pulls.
        """
        query = self._build_feed_lightweight_base_query(user_id)

        if cursor_updated_at is not None and cursor_episode_id is not None:
            boundary = _as_utc(cursor_updated_at)
            query = query.where(
                or_(
                    PodcastEpisode.updated_at > boundary,
                    and_(
                        PodcastEpisode.updated_at == boundary,
                        PodcastEpisode.id > cursor_episode_id,
                    ),
                ),
            )

        query = query.order_by(
            PodcastEpisode.updated_at.asc(),
            PodcastEpisode.id.asc(),
        ).limit(size + 1)

        result = await self.db.execute(query)
        rows = result.mappings().all()

        has_more = len(rows) > size
        trimmed_rows = rows[:size]
        items = [self._build_feed_lightweight_item(row) for row in trimmed_rows]
        # Always report the tail cursor: when has_more is false it doubles as
        # the watermark the client should persist for its next incremental
        # sync (only an empty batch keeps the client's previous watermark).
        next_cursor_values: tuple[Any, int] | None = None
        if trimmed_rows:
            tail = trimmed_rows[-1]
            next_cursor_values = (tail["updated_at"], tail["id"])

        return items, has_more, next_cursor_values
