from unittest.mock import AsyncMock

import pytest

from app.domains.ai.models import ModelType
from app.domains.ai.services import AIModelConfigService


@pytest.mark.asyncio
async def test_ai_model_config_service_delegates_management_calls():
    service = AIModelConfigService(AsyncMock())
    expected = object()
    service.management_service.get_default_model = AsyncMock(return_value=expected)

    result = await service.get_default_model(ModelType.TEXT_GENERATION)

    assert result is expected
    service.management_service.get_default_model.assert_awaited_once_with(
        ModelType.TEXT_GENERATION,
    )


@pytest.mark.asyncio
async def test_ai_model_config_service_delegates_runtime_calls(monkeypatch):
    service = AIModelConfigService(AsyncMock())
    expected = ("ok", object())
    call_mock = AsyncMock(return_value=expected)
    monkeypatch.setattr(
        "app.domains.ai.services.text_generation_service.AIModelRuntimeService"
        ".call_text_generation_with_fallback",
        call_mock,
    )

    result = await service.call_text_generation_with_fallback(
        messages=[{"role": "user", "content": "hello"}],
        max_tokens=128,
        temperature=0.2,
        model_id="3",
    )

    assert result is expected
    call_mock.assert_awaited_once_with(
        messages=[{"role": "user", "content": "hello"}],
        max_tokens=128,
        temperature=0.2,
        model_id="3",
    )


@pytest.mark.asyncio
async def test_ai_model_config_service_delegates_key_decryption():
    service = AIModelConfigService(AsyncMock())
    model = object()
    service.security_service.get_decrypted_api_key = AsyncMock(return_value="secret")

    result = await service.get_decrypted_api_key(model)

    assert result == "secret"
    service.security_service.get_decrypted_api_key.assert_awaited_once_with(model)
