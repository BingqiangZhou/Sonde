"""Tests for shared API key resolution (DB-stored keys only, no env fallback)."""

import logging
from types import SimpleNamespace

import pytest

from app.core.security import encrypt_data
from app.domains.ai.key_resolver import (
    extract_model_key,
    resolve_api_key_with_fallback,
)


def _model(
    model_id=1, api_key="sk-valid-key", encrypted=False, provider="custom", **extra
):
    return SimpleNamespace(
        id=model_id,
        name=f"model-{model_id}",
        api_key=api_key,
        api_key_encrypted=encrypted,
        provider=provider,
        **extra,
    )


def test_primary_model_plaintext_key_is_returned():
    key = resolve_api_key_with_fallback(
        primary_model=_model(),
        fallback_models=[],
        logger=logging.getLogger(__name__),
        invalid_message="no key",
    )

    assert key == "sk-valid-key"


def test_encrypted_primary_key_is_decrypted():
    key = resolve_api_key_with_fallback(
        primary_model=_model(api_key=encrypt_data("sk-secret"), encrypted=True),
        fallback_models=[],
        logger=logging.getLogger(__name__),
        invalid_message="no key",
    )

    assert key == "sk-secret"


def test_placeholder_primary_key_falls_back_to_other_models():
    fallback = _model(model_id=2, api_key="sk-other-valid")

    key = resolve_api_key_with_fallback(
        primary_model=_model(api_key="your-api-key-here"),
        fallback_models=[fallback],
        logger=logging.getLogger(__name__),
        invalid_message="no key",
    )

    assert key == "sk-other-valid"


def test_system_model_without_env_key_uses_stored_or_fallback_keys():
    """Regression guard: system preset models resolve keys like any other row."""
    system_model = _model(
        model_id=1,
        api_key="",
        provider="siliconflow",
    )
    fallback = _model(model_id=2, api_key="sk-fallback")

    key = resolve_api_key_with_fallback(
        primary_model=system_model,
        fallback_models=[fallback],
        logger=logging.getLogger(__name__),
        invalid_message="no valid key for system model",
        provider_key_prefix={"siliconflow": "sk-"},
    )

    assert key == "sk-fallback"


def test_no_valid_key_anywhere_raises():
    with pytest.raises(ValueError, match="no valid key anywhere"):
        resolve_api_key_with_fallback(
            primary_model=_model(api_key=""),
            fallback_models=[_model(model_id=2, api_key="none")],
            logger=logging.getLogger(__name__),
            invalid_message="no valid key anywhere",
        )


def test_extract_model_key_rejects_placeholders():
    assert extract_model_key(_model(api_key="your-openai-api-key-here")) is None
    assert extract_model_key(_model(api_key=None)) is None
    assert extract_model_key(_model()) == "sk-valid-key"
