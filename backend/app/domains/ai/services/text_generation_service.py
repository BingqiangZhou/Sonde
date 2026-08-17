"""AI-powered text generation, runtime invocation, and base model management.

Consolidates the former text_generation_service, model_runtime_service,
and base_model_manager into a single module.
"""

from __future__ import annotations

import logging
import time
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationError
from app.domains.ai.model_testing import (
    test_text_generation_model,
    test_transcription_model,
    validate_api_key,
)
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.ai.schemas import APIKeyValidationResponse, ModelTestResponse
from app.domains.podcast.ai_key_resolver import resolve_api_key_with_fallback

from .model_config_service import AIModelSecurityService


logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# BaseModelManager -- shared model resolution / API-key fallback patterns
# ---------------------------------------------------------------------------


class BaseModelManager:
    """Base class providing common model management functionality.

    This class encapsulates shared patterns for:
    - Model resolution by name or priority
    - API key resolution with fallback
    - Active model listing

    Subclasses should implement:
    - Specific generation/extraction methods
    - Prompt building logic
    - Response parsing logic
    """

    def __init__(
        self,
        db: AsyncSession,
        model_type: ModelType,
        operation_name: str = "AI operation",
    ):
        """Initialize the model manager.

        Args:
            db: AsyncSession for database access
            model_type: The type of AI model this manager handles
            operation_name: Human-readable name for logging (e.g., "Highlight extraction")
        """
        self.db = db
        self.model_type = model_type
        self.operation_name = operation_name
        self.ai_model_repo = AIModelConfigRepository(db)

    async def get_active_model(
        self,
        model_name: str | None = None,
        *,
        error_message: str | None = None,
    ) -> Any:
        """Get active model by name or highest priority."""
        if model_name:
            model = await self.ai_model_repo.get_by_name(model_name)
            if not model or not model.is_active or model.model_type != self.model_type:
                raise ValidationError(
                    f"{self.operation_name} model '{model_name}' not found or not active",
                )
            return model

        active_models = await self.ai_model_repo.get_active_models_by_priority(
            self.model_type,
        )
        if not active_models:
            msg = (
                error_message or f"No active {self.operation_name.lower()} model found"
            )
            raise ValidationError(msg)
        return active_models[0]

    async def get_models_to_try(
        self,
        model_name: str | None = None,
        *,
        error_message: str | None = None,
    ) -> list[Any]:
        """Get list of models to try for fallback."""
        if model_name:
            model = await self.get_active_model(model_name, error_message=error_message)
            return [model]

        models = await self.ai_model_repo.get_active_models_by_priority(
            self.model_type,
        )
        if not models:
            msg = error_message or f"No active {self.model_type.value} models available"
            raise ValidationError(msg)
        return models

    async def resolve_api_key(
        self,
        model_config: Any,
        *,
        invalid_message: str | None = None,
    ) -> str:
        """Resolve valid API key for model with fallback."""
        active_models = await self.ai_model_repo.get_active_models(
            self.model_type,
        )

        msg = invalid_message or (
            f"No valid API key found. Model '{model_config.name}' has a "
            "placeholder/invalid API key, and no alternative models with "
            f"valid API keys were found for {self.operation_name}."
        )

        try:
            return resolve_api_key_with_fallback(
                primary_model=model_config,
                fallback_models=active_models,
                logger=logger,
                invalid_message=msg,
            )
        except ValueError as exc:
            raise ValidationError(str(exc)) from exc

    async def list_available_models(self) -> list[dict[str, Any]]:
        """List all available models for this manager's model type."""
        active_models = await self.ai_model_repo.get_active_models(
            self.model_type,
        )
        return [
            {
                "id": model.id,
                "name": model.name,
                "display_name": model.display_name,
                "provider": model.provider,
                "model_id": model.model_id,
                "is_default": model.is_default,
            }
            for model in active_models
        ]


# ---------------------------------------------------------------------------
# AIModelRuntimeService -- runtime validation and testing
# ---------------------------------------------------------------------------


class AIModelRuntimeService:
    """Handle model testing, validation, and runtime fallback invocations."""

    def __init__(
        self,
        repo: AIModelConfigRepository,
        security_service: AIModelSecurityService,
    ):
        self.repo = repo
        self.security_service = security_service

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

        api_key = await self.security_service.get_decrypted_api_key(model)
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
        return await validate_api_key(api_url, api_key, model_id, model_type)
