from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.domains.podcast.models import Episode, Podcast, PodcastRankingHistory, ProcessingStatus
from app.shared.base import BaseRepository


class PodcastRepository(BaseRepository[Podcast]):
    def __init__(self, session: AsyncSession):
        super().__init__(Podcast, session)

    async def get_by_xyzrank_id(self, xyzrank_id: str) -> Podcast | None:
        result = await self.session.execute(
            select(self.model).where(self.model.xyzrank_id == xyzrank_id)
        )
        return result.scalars().first()

    async def get_tracked(self, skip: int = 0, limit: int = 100) -> list[Podcast]:
        result = await self.session.execute(
            select(self.model)
            .where(self.model.is_tracked == True)  # noqa: E712
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_rank_range(self, start: int, end: int) -> list[Podcast]:
        result = await self.session.execute(
            select(self.model)
            .where(self.model.rank >= start, self.model.rank <= end)
            .order_by(self.model.rank)
        )
        return list(result.scalars().all())

    async def search(self, query: str, skip: int = 0, limit: int = 100) -> list[Podcast]:
        result = await self.session.execute(
            select(self.model)
            .where(self.model.name.ilike(f"%{query}%"))
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def search_count(self, query: str) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(self.model).where(self.model.name.ilike(f"%{query}%"))
        )
        return result.scalar_one()

    async def get_filtered(
        self,
        *,
        skip: int = 0,
        limit: int = 100,
        category: str | None = None,
        is_tracked: bool | None = None,
        search: str | None = None,
    ) -> list[Podcast]:
        stmt = select(self.model)
        if category:
            stmt = stmt.where(self.model.category == category)
        if is_tracked is not None:
            stmt = stmt.where(self.model.is_tracked == is_tracked)
        if search:
            stmt = stmt.where(self.model.name.ilike(f"%{search}%"))
        stmt = stmt.order_by(self.model.rank).offset(skip).limit(limit)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_filtered_count(
        self,
        *,
        category: str | None = None,
        is_tracked: bool | None = None,
        search: str | None = None,
    ) -> int:
        stmt = select(func.count()).select_from(self.model)
        if category:
            stmt = stmt.where(self.model.category == category)
        if is_tracked is not None:
            stmt = stmt.where(self.model.is_tracked == is_tracked)
        if search:
            stmt = stmt.where(self.model.name.ilike(f"%{search}%"))
        result = await self.session.execute(stmt)
        return result.scalar_one()

    async def get_rankings(self, skip: int = 0, limit: int = 100) -> list[Podcast]:
        result = await self.session.execute(
            select(self.model).order_by(self.model.rank).offset(skip).limit(limit)
        )
        return list(result.scalars().all())


class PodcastRankingHistoryRepository(BaseRepository[PodcastRankingHistory]):
    def __init__(self, session: AsyncSession):
        super().__init__(PodcastRankingHistory, session)

    async def get_by_podcast(
        self, podcast_id: UUID, skip: int = 0, limit: int = 100
    ) -> list[PodcastRankingHistory]:
        result = await self.session.execute(
            select(self.model)
            .where(self.model.podcast_id == podcast_id)
            .order_by(self.model.recorded_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())


class EpisodeRepository(BaseRepository[Episode]):
    def __init__(self, session: AsyncSession):
        super().__init__(Episode, session)

    async def get_by_podcast(
        self, podcast_id: UUID, skip: int = 0, limit: int = 100
    ) -> list[Episode]:
        result = await self.session.execute(
            select(self.model)
            .where(self.model.podcast_id == podcast_id)
            .order_by(self.model.published_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def count_by_podcast(self, podcast_id: UUID) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(self.model).where(self.model.podcast_id == podcast_id)
        )
        return result.scalar_one()

    async def get_by_audio_url(self, audio_url: str) -> Episode | None:
        result = await self.session.execute(
            select(self.model).where(self.model.audio_url == audio_url)
        )
        return result.scalars().first()

    async def get_by_feed_identity(
        self,
        *,
        podcast_id: UUID,
        external_id: str | None = None,
        source_url: str | None = None,
        audio_url: str | None = None,
    ) -> Episode | None:
        identity_filters = []
        if external_id:
            identity_filters.append(self.model.external_id == external_id)
        if source_url:
            identity_filters.append(self.model.source_url == source_url)
        if audio_url:
            identity_filters.append(self.model.audio_url == audio_url)

        if not identity_filters:
            return None

        result = await self.session.execute(
            select(self.model).where(
                self.model.podcast_id == podcast_id,
                or_(*identity_filters),
            )
        )
        return result.scalars().first()

    async def get_filtered(
        self,
        *,
        skip: int = 0,
        limit: int = 100,
        podcast_id: UUID | None = None,
        transcript_status: ProcessingStatus | None = None,
        summary_status: ProcessingStatus | None = None,
    ) -> list[Episode]:
        stmt = select(self.model)
        if podcast_id:
            stmt = stmt.where(self.model.podcast_id == podcast_id)
        if transcript_status:
            stmt = stmt.where(self.model.transcript_status == transcript_status)
        if summary_status:
            stmt = stmt.where(self.model.summary_status == summary_status)
        stmt = stmt.order_by(self.model.published_at.desc()).offset(skip).limit(limit)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_filtered_count(
        self,
        *,
        podcast_id: UUID | None = None,
        transcript_status: ProcessingStatus | None = None,
        summary_status: ProcessingStatus | None = None,
    ) -> int:
        stmt = select(func.count()).select_from(self.model)
        if podcast_id:
            stmt = stmt.where(self.model.podcast_id == podcast_id)
        if transcript_status:
            stmt = stmt.where(self.model.transcript_status == transcript_status)
        if summary_status:
            stmt = stmt.where(self.model.summary_status == summary_status)
        result = await self.session.execute(stmt)
        return result.scalar_one()

    async def get_with_relations(self, id: UUID) -> Episode | None:
        result = await self.session.execute(
            select(self.model)
            .options(selectinload(self.model.podcast))
            .where(self.model.id == id)
        )
        return result.scalars().first()

    async def update_status(
        self,
        id: UUID,
        transcript_status: ProcessingStatus | None = None,
        summary_status: ProcessingStatus | None = None,
    ) -> Episode | None:
        episode = await self.get(id)
        if episode is None:
            return None
        if transcript_status is not None:
            episode.transcript_status = transcript_status
        if summary_status is not None:
            episode.summary_status = summary_status
        self.session.add(episode)
        await self.session.flush()
        return episode
