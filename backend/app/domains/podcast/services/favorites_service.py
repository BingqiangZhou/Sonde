"""Per-user 单集收藏服务（Phase B）。"""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.domains.podcast.models import PodcastEpisode, Subscription, UserFavorite


class FavoritesService:
    """收藏的增删查（user 维度隔离）。"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_favorites(
        self, user_id: int, page: int = 1, size: int = 50
    ) -> dict:
        """收藏单集列表（按收藏时间倒序，join 播客名）。"""
        base = (
            select(UserFavorite, PodcastEpisode, Subscription.title)
            .join(PodcastEpisode, UserFavorite.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .where(UserFavorite.user_id == user_id)
            .order_by(UserFavorite.created_at.desc())
        )
        total = (
            await self.db.execute(
                select(func.count())
                .select_from(UserFavorite)
                .where(UserFavorite.user_id == user_id)
            )
        ).scalar_one()

        rows = (
            await self.db.execute(base.limit(size).offset((page - 1) * size))
        ).all()

        items = []
        for fav, ep, sub_title in rows:
            items.append(
                {
                    "id": ep.id,
                    "subscription_id": ep.subscription_id,
                    "subscription_title": sub_title,
                    "title": ep.title,
                    "image_url": ep.image_url,
                    "audio_url": ep.audio_url,
                    "audio_duration": ep.audio_duration,
                    "published_at": ep.published_at,
                    "ai_summary": ep.ai_summary,
                    "favorited_at": fav.created_at,
                }
            )
        pages = (total + size - 1) // size if size else 1
        return {"items": items, "total": total, "page": page, "size": size, "pages": pages}

    async def is_favorite(self, user_id: int, episode_id: int) -> bool:
        result = await self.db.execute(
            select(UserFavorite.id).where(
                UserFavorite.user_id == user_id,
                UserFavorite.episode_id == episode_id,
            )
        )
        return result.scalar_one_or_none() is not None

    async def add_favorite(self, user_id: int, episode_id: int) -> None:
        """收藏单集；单集不存在 → 404；重复收藏幂等。"""
        episode = (
            await self.db.execute(
                select(PodcastEpisode.id).where(PodcastEpisode.id == episode_id)
            )
        ).scalar_one_or_none()
        if episode is None:
            raise NotFoundError("Episode not found")

        if not await self.is_favorite(user_id, episode_id):
            self.db.add(
                UserFavorite(
                    user_id=user_id,
                    episode_id=episode_id,
                    created_at=datetime.now(UTC),
                )
            )
            await self.db.commit()

    async def remove_favorite(self, user_id: int, episode_id: int) -> None:
        """取消收藏；未收藏时幂等。"""
        await self.db.execute(
            delete(UserFavorite).where(
                UserFavorite.user_id == user_id,
                UserFavorite.episode_id == episode_id,
            )
        )
        await self.db.commit()
