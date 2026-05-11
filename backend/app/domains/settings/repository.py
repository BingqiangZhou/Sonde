from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.domains.settings.models import AIModelConfig, AIProviderConfig, PromptTemplate
from app.shared.base import BaseRepository


class AIProviderRepository(BaseRepository[AIProviderConfig]):
    def __init__(self, session: AsyncSession):
        super().__init__(AIProviderConfig, session)

    async def get_active_providers(self) -> list[AIProviderConfig]:
        result = await self.session.execute(
            select(self.model)
            .options(selectinload(self.model.models))
            .where(self.model.is_active == True)  # noqa: E712
        )
        return list(result.scalars().all())

    async def get_multi_with_models(self, skip: int = 0, limit: int = 100) -> list[AIProviderConfig]:
        result = await self.session.execute(
            select(self.model)
            .options(selectinload(self.model.models))
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_name(self, name: str) -> AIProviderConfig | None:
        result = await self.session.execute(
            select(self.model)
            .options(selectinload(self.model.models))
            .where(self.model.name == name)
        )
        return result.scalars().first()

    async def get_with_models(self, provider_id: UUID) -> AIProviderConfig | None:
        result = await self.session.execute(
            select(self.model)
            .options(selectinload(self.model.models))
            .where(self.model.id == provider_id)
        )
        return result.scalars().first()


class AIModelRepository(BaseRepository[AIModelConfig]):
    def __init__(self, session: AsyncSession):
        super().__init__(AIModelConfig, session)

    async def get_by_provider(self, provider_id: UUID) -> list[AIModelConfig]:
        result = await self.session.execute(
            select(self.model).where(self.model.provider_id == provider_id)
        )
        return list(result.scalars().all())

    async def get_default_for_provider(self, provider_id: UUID) -> AIModelConfig | None:
        result = await self.session.execute(
            select(self.model).where(
                self.model.provider_id == provider_id,
                self.model.is_default == True,  # noqa: E712
            )
        )
        return result.scalars().first()

    async def get_first_for_provider(self, provider_id: UUID) -> AIModelConfig | None:
        result = await self.session.execute(
            select(self.model).where(self.model.provider_id == provider_id).limit(1)
        )
        return result.scalars().first()


class PromptTemplateRepository(BaseRepository[PromptTemplate]):
    def __init__(self, session: AsyncSession):
        super().__init__(PromptTemplate, session)

    async def get_active(self) -> PromptTemplate | None:
        result = await self.session.execute(
            select(self.model).where(self.model.is_active == True).limit(1)  # noqa: E712
        )
        return result.scalars().first()

    async def get_latest_version(self) -> int:
        from sqlalchemy import func as sqlfunc
        result = await self.session.execute(
            select(sqlfunc.max(self.model.version))
        )
        val = result.scalar_one()
        return val or 0


class SettingsRepository:
    """Combined repository for settings domain."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.provider_repo = AIProviderRepository(session)
        self.model_repo = AIModelRepository(session)
        self.prompt_repo = PromptTemplateRepository(session)

    async def get_active_provider(self) -> AIProviderConfig | None:
        """Get the first active provider."""
        providers = await self.provider_repo.get_active_providers()
        return providers[0] if providers else None

    async def get_default_model(self, provider_id: UUID) -> AIModelConfig | None:
        """Get the default model for a provider, or the first one."""
        model = await self.model_repo.get_default_for_provider(provider_id)
        if model is None:
            model = await self.model_repo.get_first_for_provider(provider_id)
        return model
