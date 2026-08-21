"""Summary aggregate: pending-selection and summary state transitions."""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import and_, select, update
from sqlalchemy.orm import joinedload

from app.domains.podcast.models import (
    PodcastEpisode,
)
from app.domains.podcast.repositories.base import (
    BasePodcastRepository,
    _get_subscription_models,
)


logger = logging.getLogger(__name__)


class SummaryRepository(BasePodcastRepository):
    """Summary aggregate: pending-selection and summary state transitions."""

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

    async def _get_episode(self, episode_id: int) -> PodcastEpisode | None:
        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
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
        episode = await self._get_episode(episode_id)
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
        return episode

    async def mark_summary_failed(self, episode_id: int, error: str) -> None:
        """Single source of summary-failure state.

        Marks the episode (status + metadata) and the transcription task
        (summary_error_message, surfaced to the frontend) together.
        """
        episode = await self._get_episode(episode_id)
        if episode:
            episode.status = "summary_failed"
            metadata = episode.metadata_json or {}
            metadata["summary_error"] = error
            metadata["summary_failed_at"] = datetime.now(UTC).isoformat()
            episode.metadata_json = metadata
            await self.db.commit()

        from app.domains.podcast.models import TranscriptionTask

        await self.db.execute(
            update(TranscriptionTask)
            .where(TranscriptionTask.episode_id == episode_id)
            .values(summary_error_message=error, updated_at=datetime.now(UTC))
        )
        await self.db.commit()
