"""Shared base for podcast aggregate repositories."""

from __future__ import annotations

import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import RedisCache, get_shared_redis
from app.shared.system_settings import DatabaseSettingsProvider


logger = logging.getLogger(__name__)


def _get_subscription_models():
    """Lazy import subscription models.

    Returns:
        Tuple of (Subscription, UserSubscription) models
    """
    from app.domains.podcast.models import Subscription, UserSubscription

    return Subscription, UserSubscription


def _get_user_subscription_model():
    """Lazy import UserSubscription model.

    Returns:
        UserSubscription model class
    """
    from app.domains.podcast.models import UserSubscription

    return UserSubscription


class BasePodcastRepository:
    """Shared session/redis handle and common subscription filters."""

    def __init__(
        self,
        db: AsyncSession,
        redis: RedisCache | None = None,
        settings_provider: DatabaseSettingsProvider | None = None,
    ):
        self.db = db
        self.redis = redis or get_shared_redis()
        self.settings_provider = settings_provider or DatabaseSettingsProvider()
        self._queue_position_step = 1024
        self._queue_position_compaction_threshold = 1_000_000

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

    @staticmethod
    def _normalize_optional_image_url(value: Any) -> str | None:
        if not isinstance(value, str):
            return None
        normalized = value.strip()
        return normalized or None
