"""Base model manager shared by runtime AI task managers.

Provides the common patterns for model resolution by name or priority,
API-key resolution with fallback, and active-model listing. Subclasses
(e.g. podcast's SummaryModelManager) implement the generation/parsing logic.
"""

from __future__ import annotations

import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationError
from app.domains.ai.key_resolver import resolve_api_key_with_fallback
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository


logger = logging.getLogger(__name__)


class BaseModelManager:
    """Base class providing common model management functionality."""

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
            operation_name: Human-readable name for logging (e.g., "Summary generation")
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
        from app.domains.ai.model_resolution import resolve_active_model_config

        try:
            return await resolve_active_model_config(
                self.ai_model_repo,
                model_type=self.model_type,
                model_name=model_name,
                operation_name=self.operation_name,
            )
        except ValidationError:
            # Callers may only override the no-active-models message; named
            # lookups always report the standard not-found wording.
            if model_name is None and error_message is not None:
                raise ValidationError(error_message) from None
            raise

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
