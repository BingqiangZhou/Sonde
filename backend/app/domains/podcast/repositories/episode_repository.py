"""Episode aggregate: feed-item upserts and lookups."""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import and_, desc, func, select
from sqlalchemy.orm import joinedload

from app.core.datetime_utils import (
    sanitize_published_date,
)
from app.domains.podcast.models import (
    PodcastEpisode,
)
from app.domains.podcast.repositories.base import (
    BasePodcastRepository,
    _get_subscription_models,
)


logger = logging.getLogger(__name__)


class EpisodeRepository(BasePodcastRepository):
    """Episode aggregate: feed-item upserts and lookups."""

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
        *,
        commit: bool = True,
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
        # item_link has a DB-level unique constraint; feeds sometimes repeat
        # an item — keep only the first occurrence within one batch.
        seen_item_links: set[str] = set()

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

            if item_link:
                if item_link in seen_item_links:
                    continue
                seen_item_links.add(item_link)

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
        if commit:
            await self.db.commit()

        return processed_episodes, new_episodes

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
