"""Shared API key resolution helpers for summary/transcription model managers."""

from __future__ import annotations

import logging
from collections.abc import Iterable
from typing import Any


INVALID_API_KEYS = {
    "your-openai-api-key-here",
    "your-api-key-here",
    "your-transcription-api-key-here",
    "",
    "none",
    "null",
    "your-ope************here",
}
INVALID_API_KEYS_LOWER = {placeholder.lower() for placeholder in INVALID_API_KEYS}


def is_invalid_api_key(key: str | None) -> bool:
    """Return True when API key is empty or placeholder-like."""
    if not key:
        return True
    key_lower = key.lower().strip()
    if not key_lower:
        return True
    # Keep the check conservative: only exact placeholder matches are invalid.
    # Some providers may issue real keys containing tokens like "api" or "key".
    return key_lower in INVALID_API_KEYS_LOWER


def _validate_provider_prefix(
    *,
    provider: str | None,
    key: str,
    provider_key_prefix: dict[str, str],
    logger: logging.Logger,
    model_name: str,
) -> None:
    if not provider:
        return
    expected_prefix = provider_key_prefix.get(provider)
    if expected_prefix and not key.startswith(expected_prefix):
        logger.warning(
            "API key for model %s does not start with expected prefix %s",
            model_name,
            expected_prefix,
        )


def _extract_model_key(
    *,
    model: Any,
    logger: logging.Logger,
    provider_key_prefix: dict[str, str],
) -> str | None:
    if not model or not getattr(model, "api_key", None):
        return None

    key = model.api_key
    if getattr(model, "api_key_encrypted", False):
        from app.core.security import decrypt_data

        try:
            key = decrypt_data(model.api_key)
        except Exception as exc:
            logger.error("Failed to decrypt API key for model %s: %s", model.name, exc)
            return None

    if is_invalid_api_key(key):
        return None

    _validate_provider_prefix(
        provider=getattr(model, "provider", None),
        key=key,
        provider_key_prefix=provider_key_prefix,
        logger=logger,
        model_name=getattr(model, "name", "unknown"),
    )
    return key


def resolve_api_key_with_fallback(
    *,
    primary_model: Any,
    fallback_models: Iterable[Any],
    logger: logging.Logger,
    invalid_message: str,
    provider_key_prefix: dict[str, str] | None = None,
    system_key: str | None = None,
) -> str:
    """Resolve a valid API key from primary model then fallback models."""
    prefix_rules = provider_key_prefix or {}
    if not is_invalid_api_key(system_key):
        return str(system_key)

    primary_key = _extract_model_key(
        model=primary_model,
        logger=logger,
        provider_key_prefix=prefix_rules,
    )
    if primary_key:
        return primary_key

    primary_id = getattr(primary_model, "id", None)
    for model in fallback_models:
        if getattr(model, "id", None) == primary_id:
            continue
        key = _extract_model_key(
            model=model,
            logger=logger,
            provider_key_prefix=prefix_rules,
        )
        if key:
            logger.info("Found valid API key from alternative model: %s", model.name)
            return key

    raise ValueError(invalid_message)
