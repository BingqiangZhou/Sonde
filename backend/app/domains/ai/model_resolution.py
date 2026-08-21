"""Shared active-model resolution for transcription and text generation.

Single implementation of the "by name with validation, else highest
priority" lookup used by every AI consumer (summary generation, the
transcription engine, and the workflow service). Errors raise
ValidationError so both HTTP routes and Celery handlers see domain
exceptions.
"""

from __future__ import annotations

from typing import Any

from app.core.exceptions import ValidationError
from app.domains.ai.models import ModelType


async def resolve_active_model_config(
    repo: Any,
    *,
    model_type: ModelType,
    model_name: str | None = None,
    operation_name: str = "AI model",
) -> Any:
    """Resolve one active model config by name or highest priority.

    Args:
        repo: AIModelConfigRepository (or compatible).
        model_type: Required model type.
        model_name: Optional explicit model name; must exist, be active and
            match the requested type.
        operation_name: Human-readable operation for error messages
            (e.g. "Transcription").

    Raises:
        ValidationError: Named model missing/inactive/wrong type, or no
            active model of the requested type is configured.
    """
    if model_name:
        model = await repo.get_by_name(model_name)
        if not model or not model.is_active or model.model_type != model_type:
            raise ValidationError(
                f"{operation_name} model '{model_name}' not found or not active",
            )
        return model

    active_models = await repo.get_active_models_by_priority(model_type)
    if not active_models:
        raise ValidationError(
            f"No active {operation_name.lower()} model found",
        )
    return active_models[0]
