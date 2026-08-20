"""Search read model: cross-field episode search with relevance ranking."""

from __future__ import annotations

import logging
from inspect import isawaitable
from typing import Any

from sqlalchemy import and_, case, desc, func, or_, select
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import joinedload

from app.domains.podcast.models import (
    PodcastEpisode,
)
from app.domains.podcast.repositories.base import (
    BasePodcastRepository,
    _get_subscription_models,
)


logger = logging.getLogger(__name__)

class SearchRepository(BasePodcastRepository):
    """Search read model: cross-field episode search with relevance ranking."""

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
