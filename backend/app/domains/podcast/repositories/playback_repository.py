"""Playback-state aggregate: progress, likes, and rate preferences."""

from __future__ import annotations

import logging
from datetime import UTC, date, datetime, timedelta
from typing import Any

from sqlalchemy import and_, select
from sqlalchemy.orm import joinedload

from app.core.exceptions import (
    SubscriptionNotFoundError,
)
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastPlaybackState,
)
from app.domains.podcast.repositories.base import (
    BasePodcastRepository,
    _get_subscription_models,
    _get_user_subscription_model,
)


logger = logging.getLogger(__name__)

class PlaybackStateRepository(BasePodcastRepository):
    """Playback-state aggregate: progress, likes, and rate preferences."""

    async def get_playback_state(
        self,
        user_id: int,
        episode_id: int,
    ) -> PodcastPlaybackState | None:
        """Get playback state for one user and episode."""
        stmt = select(PodcastPlaybackState).where(
            and_(
                PodcastPlaybackState.user_id == user_id,
                PodcastPlaybackState.episode_id == episode_id,
            ),
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_playback_states_batch(
        self,
        user_id: int,
        episode_ids: list[int],
    ) -> dict[int, PodcastPlaybackState]:
        """Batch fetch playback states for multiple episodes."""
        if not episode_ids:
            return {}

        stmt = select(PodcastPlaybackState).where(
            and_(
                PodcastPlaybackState.user_id == user_id,
                PodcastPlaybackState.episode_id.in_(episode_ids),
            ),
        )
        result = await self.db.execute(stmt)
        states = result.scalars().all()
        return {state.episode_id: state for state in states}

    async def get_recently_played(
        self,
        user_id: int,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        Subscription, UserSubscription = _get_subscription_models()
        stmt = (
            select(
                PodcastEpisode,
                PodcastPlaybackState.current_position,
                PodcastPlaybackState.last_updated_at,
            )
            .join(PodcastPlaybackState)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(joinedload(PodcastEpisode.subscription))
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    PodcastPlaybackState.last_updated_at
                    >= datetime.now(UTC) - timedelta(days=7),
                ),
            )
            .order_by(PodcastPlaybackState.last_updated_at.desc())
            .limit(limit)
        )

        result = await self.db.execute(stmt)
        rows = result.unique().all()
        recently_played = []
        for episode, position, last_played in rows:
            sub_title = episode.subscription.title if episode.subscription else None
            recently_played.append(
                {
                    "episode_id": episode.id,
                    "title": episode.title,
                    "subscription_title": sub_title,
                    "position": position,
                    "last_played": last_played,
                    "duration": episode.audio_duration,
                },
            )
        return recently_played

    async def get_liked_episodes(
        self,
        user_id: int,
        limit: int = 20,
    ) -> list[PodcastEpisode]:
        Subscription, UserSubscription = _get_subscription_models()
        stmt = (
            select(PodcastEpisode)
            .join(PodcastPlaybackState)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(joinedload(PodcastEpisode.subscription))
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    PodcastEpisode.audio_duration > 0,
                    PodcastPlaybackState.current_position
                    >= PodcastEpisode.audio_duration * 0.8,
                ),
            )
            .order_by(PodcastPlaybackState.play_count.desc())
            .limit(limit)
        )

        result = await self.db.execute(stmt)
        return list(result.scalars().unique().all())

    async def get_recent_play_dates(self, user_id: int, days: int = 30) -> set[date]:
        stmt = (
            select(PodcastPlaybackState.last_updated_at)
            .where(
                and_(
                    PodcastPlaybackState.user_id == user_id,
                    PodcastPlaybackState.last_updated_at
                    >= datetime.now(UTC) - timedelta(days=days),
                ),
            )
            .distinct()
        )

        result = await self.db.execute(stmt)
        dates = set()
        for (last_updated,) in result:
            dates.add(last_updated.date())
        return dates

    async def update_playback_progress(
        self,
        user_id: int,
        episode_id: int,
        position: int,
        is_playing: bool = False,
        playback_rate: float = 1.0,
    ) -> PodcastPlaybackState:
        # Use SELECT ... FOR UPDATE to prevent race condition on concurrent
        # progress updates for the same user+episode pair.
        stmt = (
            select(PodcastPlaybackState)
            .where(
                PodcastPlaybackState.user_id == user_id,
                PodcastPlaybackState.episode_id == episode_id,
            )
            .with_for_update()
        )
        result = await self.db.execute(stmt)
        state = result.scalar_one_or_none()

        if state is not None:
            was_playing = bool(state.is_playing)
            state.current_position = position
            state.playback_rate = playback_rate
            if not was_playing and is_playing:
                state.play_count += 1
            state.is_playing = is_playing
            state.last_updated_at = datetime.now(UTC)
            await self.db.flush()
        else:
            state = PodcastPlaybackState(
                user_id=user_id,
                episode_id=episode_id,
                current_position=position,
                is_playing=is_playing,
                playback_rate=playback_rate,
                play_count=1 if is_playing else 0,
                last_updated_at=datetime.now(UTC),
            )
            self.db.add(state)
            await self.db.flush()

        await self.db.commit()

        return state

    async def get_user_default_playback_rate(self, user_id: int) -> float:
        # Hardcoded default playback rate for single-user mode
        return 1.0

    async def get_subscription_playback_rate_preference(
        self,
        user_id: int,
        subscription_id: int,
    ) -> float | None:
        UserSubscription = _get_user_subscription_model()
        stmt = select(UserSubscription.playback_rate_preference).where(
            and_(
                *self._active_user_subscription_filters(user_id),
                UserSubscription.subscription_id == subscription_id,
            ),
        )
        result = await self.db.execute(stmt)
        value = result.scalar_one_or_none()
        return float(value) if value is not None else None

    async def get_effective_playback_rate(
        self,
        user_id: int,
        subscription_id: int | None = None,
    ) -> dict[str, Any]:
        global_rate = await self.get_user_default_playback_rate(user_id)
        subscription_rate: float | None = None
        source = "global"
        effective_rate = global_rate

        if subscription_id is not None:
            subscription_rate = await self.get_subscription_playback_rate_preference(
                user_id=user_id,
                subscription_id=subscription_id,
            )
            if subscription_rate is not None:
                source = "subscription"
                effective_rate = subscription_rate
            elif global_rate == 1.0:
                source = "default"
        elif global_rate == 1.0:
            source = "default"

        return {
            "global_playback_rate": global_rate,
            "subscription_playback_rate": subscription_rate,
            "effective_playback_rate": effective_rate,
            "source": source,
        }

    async def apply_playback_rate_preference(
        self,
        user_id: int,
        playback_rate: float,
        apply_to_subscription: bool,
        subscription_id: int | None = None,
    ) -> dict[str, Any]:
        UserSubscription = _get_user_subscription_model()
        if apply_to_subscription:
            if subscription_id is None:
                raise ValueError("SUBSCRIPTION_ID_REQUIRED")

            stmt = select(UserSubscription).where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    UserSubscription.subscription_id == subscription_id,
                ),
            )
            result = await self.db.execute(stmt)
            user_sub = result.scalar_one_or_none()
            if user_sub is None:
                raise SubscriptionNotFoundError("Subscription not found")

            user_sub.playback_rate_preference = playback_rate
            await self.db.commit()
            return await self.get_effective_playback_rate(user_id, subscription_id)

        # In single-user mode, global playback rate is not stored
        # Just return the current effective rate
        return await self.get_effective_playback_rate(user_id, subscription_id)
