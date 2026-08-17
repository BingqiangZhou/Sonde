"""AI model configuration, catalog management, and security services.

Consolidates the former model_config_service, model_management_service,
and model_security_service into a single module.
"""

from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import ValidationError
from app.domains.ai.models import AIModelConfig, ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.ai.schemas import (
    AIModelConfigCreate,
    AIModelConfigUpdate,
    APIKeyValidationResponse,
    ModelUsageStats,
    PresetModelConfig,
)


logger = logging.getLogger(__name__)


class AIModelSecurityService:
    """Handle API-key encryption, decryption, and default-model state."""

    def __init__(self, db: AsyncSession):
        self.db = db

    def encrypt_api_key(self, api_key: str) -> str:
        """Encrypt a user-provided API key for storage."""
        from app.core.security import encrypt_data

        return encrypt_data(api_key)

    async def get_decrypted_api_key(self, model: AIModelConfig) -> str:
        """Resolve the decrypted API key for runtime use."""
        if not model.api_key_encrypted:
            return model.api_key

        if model.is_system:
            return self.get_preset_api_key_from_env(model.name)

        from app.core.security import decrypt_data

        try:
            decrypted = decrypt_data(model.api_key)
            logger.debug("API key decrypted for model %s", model.name)
            return decrypted
        except Exception as exc:
            logger.error("Failed to decrypt API key for model %s: %s", model.name, exc)
            raise ValidationError(
                f"Failed to decrypt API key for model {model.name}",
            ) from exc

    async def clear_default_models(self, model_type: ModelType) -> None:
        """Unset existing default models for a model type."""
        stmt = (
            update(AIModelConfig)
            .where(AIModelConfig.model_type == model_type, AIModelConfig.is_default)
            .values(is_default=False)
        )
        await self.db.execute(stmt)
        await self.db.commit()

    def get_preset_api_key(self, preset: PresetModelConfig) -> str | None:
        """Resolve a preset-model API key from environment settings."""
        if preset.provider == "openai":
            return getattr(settings, "OPENAI_API_KEY", None)
        if preset.provider == "siliconflow":
            return getattr(settings, "TRANSCRIPTION_API_KEY", None)
        return None

    def get_preset_api_key_from_env(self, model_name: str) -> str | None:
        """Resolve a preset-model API key by well-known model name."""
        if model_name in ["whisper-1", "gpt-4o-mini", "gpt-4o", "gpt-3.5-turbo"]:
            return getattr(settings, "OPENAI_API_KEY", None)
        if model_name == "sensevoice-small":
            return getattr(settings, "TRANSCRIPTION_API_KEY", None)
        return None


class AIModelManagementService:
    """Manage AI model configuration lifecycle and catalog queries."""

    def __init__(
        self,
        repo: AIModelConfigRepository,
        security_service: AIModelSecurityService,
    ):
        self.repo = repo
        self.security_service = security_service

    async def create_model(self, model_data: AIModelConfigCreate) -> AIModelConfig:
        """Create a new model configuration."""
        existing_model = await self.repo.get_by_name(model_data.name)
        if existing_model:
            raise ValidationError(f"Model with name '{model_data.name}' already exists")

        if model_data.is_default:
            await self.security_service.clear_default_models(model_data.model_type)

        encrypted_key = None
        if model_data.api_key:
            encrypted_key = self.security_service.encrypt_api_key(model_data.api_key)
            logger.debug("API key processed for model %s", model_data.name)

        model_config = AIModelConfig(
            name=model_data.name,
            display_name=model_data.display_name,
            description=model_data.description,
            model_type=model_data.model_type,
            api_url=model_data.api_url,
            api_key=encrypted_key or "",
            api_key_encrypted=bool(model_data.api_key),
            model_id=model_data.model_id,
            provider=model_data.provider,
            max_tokens=model_data.max_tokens,
            temperature=model_data.temperature,
            timeout_seconds=model_data.timeout_seconds,
            max_retries=model_data.max_retries,
            max_concurrent_requests=model_data.max_concurrent_requests,
            rate_limit_per_minute=model_data.rate_limit_per_minute,
            cost_per_input_token=model_data.cost_per_input_token,
            cost_per_output_token=model_data.cost_per_output_token,
            extra_config=model_data.extra_config or {},
            is_active=model_data.is_active,
            is_default=model_data.is_default,
            priority=model_data.priority,
            is_system=False,
        )
        return await self.repo.create(model_config)

    async def get_model_by_id(self, model_id: int) -> AIModelConfig | None:
        return await self.repo.get_by_id(model_id)

    async def get_models(
        self,
        model_type: ModelType | None = None,
        is_active: bool | None = None,
        provider: str | None = None,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[AIModelConfig], int]:
        return await self.repo.get_list(
            model_type=model_type,
            is_active=is_active,
            provider=provider,
            page=page,
            size=size,
        )

    async def search_models(
        self,
        query: str,
        model_type: ModelType | None = None,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[AIModelConfig], int]:
        return await self.repo.search_models(
            query=query,
            model_type=model_type,
            page=page,
            size=size,
        )

    async def update_model(
        self,
        model_id: int,
        model_data: AIModelConfigUpdate,
    ) -> AIModelConfig | None:
        existing_model = await self.repo.get_by_id(model_id)
        if not existing_model:
            return None

        if model_data.is_default:
            await self.security_service.clear_default_models(existing_model.model_type)

        update_data = model_data.dict(exclude_unset=True)
        if "api_key" in update_data:
            if update_data["api_key"]:
                update_data["api_key"] = self.security_service.encrypt_api_key(
                    update_data["api_key"],
                )
                update_data["api_key_encrypted"] = True
                logger.debug("API key updated for model %s", model_id)
            else:
                update_data["api_key"] = ""
                update_data["api_key_encrypted"] = False

        return await self.repo.update(model_id, update_data)

    async def delete_model(self, model_id: int) -> bool:
        return await self.repo.delete(model_id)

    async def set_default_model(
        self,
        model_id: int,
        model_type: ModelType,
    ) -> AIModelConfig | None:
        success = await self.repo.set_default_model(model_id, model_type)
        if success:
            return await self.repo.get_by_id(model_id)
        return None

    async def get_default_model(self, model_type: ModelType) -> AIModelConfig | None:
        return await self.repo.get_default_model(model_type)

    async def get_active_models(
        self,
        model_type: ModelType | None = None,
    ) -> list[AIModelConfig]:
        return await self.repo.get_active_models(model_type)

    async def get_model_stats(self, model_id: int) -> ModelUsageStats | None:
        model = await self.repo.get_by_id(model_id)
        if not model:
            return None

        success_rate = 0.0
        if model.usage_count > 0:
            success_rate = (model.success_count / model.usage_count) * 100

        return ModelUsageStats(
            model_id=model.id,
            model_name=model.name,
            model_type=model.model_type,
            usage_count=model.usage_count,
            success_count=model.success_count,
            error_count=model.error_count,
            success_rate=success_rate,
            total_tokens_used=model.total_tokens_used,
            last_used_at=model.last_used_at,
        )

    async def get_type_stats(
        self,
        model_type: ModelType,
        limit: int = 20,
    ) -> list[ModelUsageStats]:
        stats_data = await self.repo.get_usage_stats(model_type, limit)
        return [ModelUsageStats(**stat) for stat in stats_data]

    async def init_default_models(self) -> list[AIModelConfig]:
        """Default bootstrap remains disabled until presets are reintroduced."""
        return []


class AIModelConfigService:
    """Thin orchestration facade preserving the historical public service API."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = AIModelConfigRepository(db)
        self.security_service = AIModelSecurityService(db)
        self.management_service = AIModelManagementService(
            repo=self.repo,
            security_service=self.security_service,
        )

    async def create_model(self, model_data: AIModelConfigCreate) -> AIModelConfig:
        return await self.management_service.create_model(model_data)

    async def get_model_by_id(self, model_id: int) -> AIModelConfig | None:
        return await self.management_service.get_model_by_id(model_id)

    async def get_models(
        self,
        model_type: ModelType | None = None,
        is_active: bool | None = None,
        provider: str | None = None,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[AIModelConfig], int]:
        return await self.management_service.get_models(
            model_type=model_type,
            is_active=is_active,
            provider=provider,
            page=page,
            size=size,
        )

    async def search_models(
        self,
        query: str,
        model_type: ModelType | None = None,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[AIModelConfig], int]:
        return await self.management_service.search_models(
            query=query,
            model_type=model_type,
            page=page,
            size=size,
        )

    async def update_model(
        self,
        model_id: int,
        model_data: AIModelConfigUpdate,
    ) -> AIModelConfig | None:
        return await self.management_service.update_model(model_id, model_data)

    async def delete_model(self, model_id: int) -> bool:
        return await self.management_service.delete_model(model_id)

    async def set_default_model(
        self,
        model_id: int,
        model_type: ModelType,
    ) -> AIModelConfig | None:
        return await self.management_service.set_default_model(model_id, model_type)

    async def get_default_model(self, model_type: ModelType) -> AIModelConfig | None:
        return await self.management_service.get_default_model(model_type)

    async def get_active_models(
        self,
        model_type: ModelType | None = None,
    ) -> list[AIModelConfig]:
        return await self.management_service.get_active_models(model_type)

    async def test_model(
        self,
        model_id: int,
        test_data: dict[str, Any] | None = None,
    ) -> Any:
        # Lazy import to avoid circular dependency with text_generation_service
        from .text_generation_service import AIModelRuntimeService

        runtime_service = AIModelRuntimeService(
            repo=self.repo,
            security_service=self.security_service,
        )
        return await runtime_service.test_model(model_id, test_data)

    async def get_model_stats(self, model_id: int) -> ModelUsageStats | None:
        return await self.management_service.get_model_stats(model_id)

    async def get_type_stats(
        self,
        model_type: ModelType,
        limit: int = 20,
    ) -> list[ModelUsageStats]:
        return await self.management_service.get_type_stats(model_type, limit)

    async def init_default_models(self) -> list[AIModelConfig]:
        return await self.management_service.init_default_models()

    async def get_decrypted_api_key(self, model: AIModelConfig) -> str:
        return await self.security_service.get_decrypted_api_key(model)

    async def validate_api_key(
        self,
        api_url: str,
        api_key: str,
        model_id: str | None,
        model_type: ModelType,
    ) -> APIKeyValidationResponse:
        # Lazy import to avoid circular dependency with text_generation_service
        from .text_generation_service import AIModelRuntimeService

        runtime_service = AIModelRuntimeService(
            repo=self.repo,
            security_service=self.security_service,
        )
        return await runtime_service.validate_api_key(
            api_url=api_url,
            api_key=api_key,
            model_id=model_id,
            model_type=model_type,
        )
