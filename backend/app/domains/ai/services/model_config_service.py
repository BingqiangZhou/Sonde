"""AI model configuration service.

Single service covering the model-config lifecycle, API-key encryption,
catalog queries, usage stats, and model testing/validation. Formerly split
across model_config/model_management/model_security services.
"""

from __future__ import annotations

import logging
import time
from typing import Any

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationError
from app.domains.ai.model_testing import (
    test_text_generation_model,
    test_transcription_model,
)
from app.domains.ai.model_testing import (
    validate_api_key as _validate_api_key_impl,
)
from app.domains.ai.models import AIModelConfig, ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.ai.schemas import (
    AIModelConfigCreate,
    AIModelConfigUpdate,
    APIKeyValidationResponse,
    ModelTestResponse,
    ModelUsageStats,
)


logger = logging.getLogger(__name__)


class AIModelConfigService:
    """Manage AI model configurations and their API keys."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = AIModelConfigRepository(db)

    # ── API key security ──────────────────────────────────────────────────────

    def _encrypt_api_key(self, api_key: str) -> str:
        """Encrypt a user-provided API key for storage."""
        from app.core.security import encrypt_data

        return encrypt_data(api_key)

    async def get_decrypted_api_key(self, model: AIModelConfig) -> str:
        """Resolve the decrypted API key for runtime use."""
        if not model.api_key_encrypted:
            return model.api_key

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

    async def _clear_default_models(self, model_type: ModelType) -> None:
        """Unset existing default models for a model type."""
        stmt = (
            update(AIModelConfig)
            .where(AIModelConfig.model_type == model_type, AIModelConfig.is_default)
            .values(is_default=False)
        )
        await self.db.execute(stmt)
        await self.db.commit()

    # ── Lifecycle ──────────────────────────────────────────────────────────────

    async def create_model(self, model_data: AIModelConfigCreate) -> AIModelConfig:
        """Create a new model configuration."""
        existing_model = await self.repo.get_by_name(model_data.name)
        if existing_model:
            raise ValidationError(f"Model with name '{model_data.name}' already exists")

        if model_data.is_default:
            await self._clear_default_models(model_data.model_type)

        encrypted_key = None
        if model_data.api_key:
            encrypted_key = self._encrypt_api_key(model_data.api_key)
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
            max_concurrent_requests=model_data.max_concurrent_requests,
            extra_config=model_data.extra_config or {},
            is_active=model_data.is_active,
            is_default=model_data.is_default,
            priority=model_data.priority,
        )
        return await self.repo.create(model_config)

    async def update_model(
        self,
        model_id: int,
        model_data: AIModelConfigUpdate,
    ) -> AIModelConfig | None:
        existing_model = await self.repo.get_by_id(model_id)
        if not existing_model:
            return None

        if model_data.is_default:
            await self._clear_default_models(existing_model.model_type)

        update_data = model_data.dict(exclude_unset=True)
        if "api_key" in update_data:
            if update_data["api_key"]:
                update_data["api_key"] = self._encrypt_api_key(update_data["api_key"])
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

    async def init_default_models(self) -> list[AIModelConfig]:
        """Default bootstrap remains disabled until presets are reintroduced."""
        return []

    # ── Catalog queries ────────────────────────────────────────────────────────

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

    async def get_default_model(self, model_type: ModelType) -> AIModelConfig | None:
        return await self.repo.get_default_model(model_type)

    async def get_active_models(
        self,
        model_type: ModelType | None = None,
    ) -> list[AIModelConfig]:
        return await self.repo.get_active_models(model_type)

    # ── Usage stats ────────────────────────────────────────────────────────────

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

    # ── Testing / validation ───────────────────────────────────────────────────

    async def test_model(
        self,
        model_id: int,
        test_data: dict[str, Any] | None = None,
    ) -> ModelTestResponse:
        if test_data is None:
            test_data = {}

        model = await self.repo.get_by_id(model_id)
        if not model:
            raise ValidationError(f"Model {model_id} not found")
        if not model.is_active:
            raise ValidationError(f"Model {model_id} is not active")

        api_key = await self.get_decrypted_api_key(model)
        started_at = time.time()

        try:
            if model.model_type == ModelType.TRANSCRIPTION:
                result = await test_transcription_model(model, api_key, test_data)
            else:
                result = await test_text_generation_model(model, api_key, test_data)

            await self.repo.increment_usage(model_id, success=True)
            return ModelTestResponse(
                success=True,
                response_time_ms=(time.time() - started_at) * 1000,
                result=result,
            )
        except (ValueError, RuntimeError, OSError) as exc:
            await self.repo.increment_usage(model_id, success=False)
            logger.error("Model test failed: %s", exc)
            return ModelTestResponse(
                success=False,
                response_time_ms=(time.time() - started_at) * 1000,
                error_message=str(exc),
            )

    async def validate_api_key(
        self,
        api_url: str,
        api_key: str,
        model_id: str | None,
        model_type: ModelType,
    ) -> APIKeyValidationResponse:
        return await _validate_api_key_impl(api_url, api_key, model_id, model_type)
