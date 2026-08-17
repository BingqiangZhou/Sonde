"""Tests for app.core.ai_client module.

Tests call_ai_api, call_ai_api_with_retry, and AIClientService.
"""

from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import pytest_asyncio

from app.core.ai_client import (
    AIClientService,
    RetryableAIModelError,
    call_ai_api,
    call_ai_api_with_retry,
    is_retryable_http_status,
    looks_like_html_error_page,
)
from app.domains.ai.models import ModelType


# ── Unit: pure functions ─────────────────────────────────────────────


class TestIsRetryableHttpStatus:
    def test_5xx_retryable(self):
        assert is_retryable_http_status(500) is True
        assert is_retryable_http_status(502) is True
        assert is_retryable_http_status(599) is True

    def test_4xx_not_retryable(self):
        assert is_retryable_http_status(400) is False
        assert is_retryable_http_status(401) is False
        assert is_retryable_http_status(403) is False

    def test_specific_retryable_codes(self):
        assert is_retryable_http_status(408) is True
        assert is_retryable_http_status(409) is True
        assert is_retryable_http_status(425) is True
        assert is_retryable_http_status(429) is True


class TestLooksLikeHtmlErrorPage:
    def test_html_markers(self):
        assert (
            looks_like_html_error_page("<!doctype html><html><body>Error</body></html>")
            is True
        )
        assert (
            looks_like_html_error_page("<html><head></head><body>5xx</body></html>")
            is True
        )

    def test_cloudflare_markers(self):
        assert looks_like_html_error_page("cloudflare error 524") is True
        assert looks_like_html_error_page("check /cdn-cgi/ for details") is True

    def test_normal_text_not_html(self):
        assert looks_like_html_error_page("This is a normal response") is False
        assert looks_like_html_error_page("") is False
        assert looks_like_html_error_page("just some text") is False


# ── Helpers ───────────────────────────────────────────────────────────


class _FakeResponse:
    """Lightweight aiohttp response stand-in.

    Doubles as its own async context manager so ``async with post(...) as resp``
    works when post() returns this object directly.
    """

    def __init__(self, status: int, text: str, content_type: str = "application/json"):
        self.status = status
        self._text = text
        self.headers = {"Content-Type": content_type}

    async def text(self):
        return self._text

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args, **kwargs):
        pass


def _make_model_config(**overrides: Any) -> Any:
    """Create a mock model config object."""
    defaults = {
        "api_url": "https://api.example.com/v1",
        "model_id": "test-model",
        "timeout_seconds": 30,
        "max_tokens": 1000,
        "extra_config": None,
    }
    defaults.update(overrides)
    config = MagicMock()
    for key, val in defaults.items():
        setattr(config, key, val)
    config.temperature = 0.7
    return config


def _make_mock_session(response: _FakeResponse):
    """Create a mock aiohttp session whose post() returns the response as async ctx mgr."""
    session = MagicMock()
    session.post = MagicMock(return_value=response)
    return session


def _make_model(name="gpt-4o", provider="openai", priority=1) -> MagicMock:
    """Create a mock AI model config."""
    model = MagicMock()
    model.name = name
    model.display_name = name
    model.provider = provider
    model.priority = priority
    model.api_url = "https://api.example.com/v1"
    model.model_id = name
    model.timeout_seconds = 30
    model.max_tokens = 1000
    model.is_active = True
    model.extra_config = None
    model.temperature = 0.7
    return model


@pytest_asyncio.fixture
async def ai_client_service():
    """AIClientService with mocked repo and security."""
    repo = AsyncMock()
    security = AsyncMock()
    service = AIClientService(repo, security)
    yield service, repo, security


# ── Unit: call_ai_api ──────────────────────────────────────────────────


class TestCallAiApi:
    async def test_success(self):
        model_config = _make_model_config()
        mock_response = _FakeResponse(
            status=200,
            text='{"choices": [{"message": {"content": "Hello world"}}]}',
        )
        mock_session = _make_mock_session(mock_response)

        with patch(
            "app.core.ai_client.get_shared_http_session",
            AsyncMock(return_value=mock_session),
        ):
            result = await call_ai_api(model_config, "test-key", "Say hello")
        assert result == "Hello world"

    async def test_retryable_error(self):
        model_config = _make_model_config()
        mock_response = _FakeResponse(status=500, text="Server Error")
        mock_session = _make_mock_session(mock_response)

        with (
            patch(
                "app.core.ai_client.get_shared_http_session",
                AsyncMock(return_value=mock_session),
            ),
            pytest.raises(RetryableAIModelError),
        ):
            await call_ai_api(model_config, "test-key", "Say hello")

    async def test_401_raises_http_exception(self):
        model_config = _make_model_config()
        mock_response = _FakeResponse(status=401, text="Unauthorized")
        mock_session = _make_mock_session(mock_response)

        with (
            patch(
                "app.core.ai_client.get_shared_http_session",
                AsyncMock(return_value=mock_session),
            ),
            pytest.raises(Exception, match="AI service error"),
        ):
            await call_ai_api(model_config, "test-key", "Say hello")

    async def test_html_error_page(self):
        model_config = _make_model_config()
        mock_response = _FakeResponse(
            status=200,
            text="<!doctype html><html>Cloudflare Error</html>",
            content_type="text/html",
        )
        mock_session = _make_mock_session(mock_response)

        with (
            patch(
                "app.core.ai_client.get_shared_http_session",
                AsyncMock(return_value=mock_session),
            ),
            pytest.raises(Exception, match="HTML error page"),
        ):
            await call_ai_api(model_config, "test-key", "Say hello")

    async def test_prompt_truncation(self):
        model_config = _make_model_config()
        long_prompt = "x" * 100

        mock_response = _FakeResponse(
            status=200,
            text='{"choices": [{"message": {"content": "ok"}}]}',
        )
        mock_session = _make_mock_session(mock_response)

        with patch("app.core.ai_client.settings") as mock_settings:
            mock_settings.AI_CLIENT_MAX_PROMPT_LENGTH = 50
            with patch(
                "app.core.ai_client.get_shared_http_session",
                AsyncMock(return_value=mock_session),
            ):
                result = await call_ai_api(model_config, "test-key", long_prompt)
        assert result == "ok"


# ── Unit: call_ai_api_with_retry ─────────────────────────────────────────


class TestCallAiApiWithRetry:
    async def test_success_first_attempt(self):
        model_config = _make_model_config()
        mock_response = _FakeResponse(
            status=200,
            text='{"choices": [{"message": {"content": "result"}}]}',
        )
        mock_session = _make_mock_session(mock_response)
        response_parser = AsyncMock(return_value="parsed")
        ai_model_repo = AsyncMock()

        with patch(
            "app.core.ai_client.get_shared_http_session",
            AsyncMock(return_value=mock_session),
        ):
            parsed, time_taken, tokens = await call_ai_api_with_retry(
                model_config,
                "test-key",
                "prompt",
                response_parser,
                ai_model_repo,
            )
        assert parsed == "parsed"

    async def test_retries_on_transient_error(self):
        model_config = _make_model_config()
        success_response = _FakeResponse(
            status=200,
            text='{"choices": [{"message": {"content": "ok"}}]}',
        )
        error_response = _FakeResponse(status=500, text="Error")

        # Use side_effect list — each call returns a _FakeResponse (sync, no coroutine)
        mock_session = MagicMock()
        mock_session.post = MagicMock(
            side_effect=[
                error_response,
                error_response,
                success_response,
            ]
        )

        response_parser = AsyncMock(return_value="parsed")
        ai_model_repo = AsyncMock()

        with (
            patch(
                "app.core.ai_client.get_shared_http_session",
                AsyncMock(return_value=mock_session),
            ),
            patch("app.core.ai_client.settings") as mock_settings,
        ):
            mock_settings.AI_CLIENT_MAX_RETRIES = 3
            mock_settings.AI_CLIENT_BASE_DELAY = 0
            mock_settings.AI_CLIENT_MAX_PROMPT_LENGTH = 1000000
            with patch("app.core.ai_client.asyncio.sleep", AsyncMock()):
                parsed, _, _ = await call_ai_api_with_retry(
                    model_config,
                    "test-key",
                    "prompt",
                    response_parser,
                    ai_model_repo,
                )
        assert parsed == "parsed"

    async def test_non_retryable_error_raises_immediately(self):
        model_config = _make_model_config()
        mock_response = _FakeResponse(status=401, text="Unauthorized")
        mock_session = _make_mock_session(mock_response)
        response_parser = AsyncMock(return_value="parsed")
        ai_model_repo = AsyncMock()

        with (
            patch(
                "app.core.ai_client.get_shared_http_session",
                AsyncMock(return_value=mock_session),
            ),
            pytest.raises(Exception, match="AI service error"),
        ):
            await call_ai_api_with_retry(
                model_config,
                "test-key",
                "prompt",
                response_parser,
                ai_model_repo,
            )


# ── Unit: AIClientService ──────────────────────────────────────────────


class TestAIClientService:
    async def test_call_with_fallback_success_first_model(self, ai_client_service):
        service, repo, security = ai_client_service
        model = _make_model()
        repo.get_active_models_by_priority = AsyncMock(return_value=[model])
        security.get_decrypted_api_key = AsyncMock(return_value="test-key")

        mock_resp = _FakeResponse(
            status=200,
            text='{"choices": [{"message": {"content": "Hello"}}]}',
        )
        mock_session = _make_mock_session(mock_resp)

        with patch(
            "app.core.ai_client.get_shared_http_session",
            AsyncMock(return_value=mock_session),
        ):
            content, returned_model = await service.call_with_fallback(
                messages=[{"role": "user", "content": "hi"}],
                model_type=ModelType.TEXT_GENERATION,
            )
        assert content == "Hello"
        assert returned_model == model

    async def test_call_with_fallback_by_model_name(self, ai_client_service):
        service, repo, security = ai_client_service
        model = _make_model(name="gpt-4o-mini")
        repo.get_by_name = AsyncMock(return_value=model)
        security.get_decrypted_api_key = AsyncMock(return_value="test-key")

        mock_resp = _FakeResponse(
            status=200,
            text='{"choices": [{"message": {"content": "Mini response"}}]}',
        )
        mock_session = _make_mock_session(mock_resp)

        with patch(
            "app.core.ai_client.get_shared_http_session",
            AsyncMock(return_value=mock_session),
        ):
            content, returned_model = await service.call_with_fallback(
                messages=[{"role": "user", "content": "hi"}],
                model_name="gpt-4o-mini",
            )
        assert content == "Mini response"

    async def test_call_with_fallback_skips_model_with_no_key(self, ai_client_service):
        service, repo, security = ai_client_service
        model_a = _make_model(name="model-a")
        model_b = _make_model(name="model-b", priority=2)
        repo.get_active_models_by_priority = AsyncMock(return_value=[model_a, model_b])

        async def _get_key(m):
            if m.name == "model-a":
                return None
            return "test-key"

        security.get_decrypted_api_key = AsyncMock(side_effect=_get_key)

        mock_resp = _FakeResponse(
            status=200,
            text='{"choices": [{"message": {"content": "Fallback"}}]}',
        )
        mock_session = _make_mock_session(mock_resp)

        with patch(
            "app.core.ai_client.get_shared_http_session",
            AsyncMock(return_value=mock_session),
        ):
            content, returned_model = await service.call_with_fallback(
                messages=[{"role": "user", "content": "hi"}],
                model_type=ModelType.TEXT_GENERATION,
            )
        assert content == "Fallback"
        assert returned_model == model_b

    async def test_call_with_fallback_all_fail_raises(self, ai_client_service):
        from app.core.exceptions import ValidationError

        service, repo, security = ai_client_service
        model = _make_model()
        repo.get_active_models_by_priority = AsyncMock(return_value=[model])
        security.get_decrypted_api_key = AsyncMock(return_value="test-key")

        mock_resp = _FakeResponse(status=500, text="Error")
        mock_session = _make_mock_session(mock_resp)

        with (
            patch(
                "app.core.ai_client.get_shared_http_session",
                AsyncMock(return_value=mock_session),
            ),
            patch("app.core.ai_client.asyncio.sleep", AsyncMock()),
            patch("app.core.ai_client.settings") as mock_settings,
        ):
            mock_settings.AI_CLIENT_MAX_RETRIES = 1
            mock_settings.AI_CLIENT_BASE_DELAY = 0
            with pytest.raises(ValidationError, match="models failed"):
                await service.call_with_fallback(
                    messages=[{"role": "user", "content": "hi"}],
                    model_type=ModelType.TEXT_GENERATION,
                )

    async def test_call_with_fallback_uses_fallback_handler(self, ai_client_service):
        service, repo, security = ai_client_service
        model = _make_model()
        repo.get_active_models_by_priority = AsyncMock(return_value=[model])
        security.get_decrypted_api_key = AsyncMock(return_value="test-key")

        mock_resp = _FakeResponse(status=500, text="Error")
        mock_session = _make_mock_session(mock_resp)
        fallback = AsyncMock(return_value="fallback response")

        with (
            patch(
                "app.core.ai_client.get_shared_http_session",
                AsyncMock(return_value=mock_session),
            ),
            patch("app.core.ai_client.asyncio.sleep", AsyncMock()),
            patch("app.core.ai_client.settings") as mock_settings,
        ):
            mock_settings.AI_CLIENT_MAX_RETRIES = 1
            mock_settings.AI_CLIENT_BASE_DELAY = 0
            content, returned_model = await service.call_with_fallback(
                messages=[{"role": "user", "content": "hi"}],
                model_type=ModelType.TEXT_GENERATION,
                fallback_handler=fallback,
            )
        assert content == "fallback response"
        assert returned_model is None

    async def test_call_with_fallback_post_process(self, ai_client_service):
        service, repo, security = ai_client_service
        model = _make_model()
        repo.get_active_models_by_priority = AsyncMock(return_value=[model])
        security.get_decrypted_api_key = AsyncMock(return_value="test-key")

        mock_resp = _FakeResponse(
            status=200,
            text='{"choices": [{"message": {"content": "hello"}}]}',
        )
        mock_session = _make_mock_session(mock_resp)

        custom_post = AsyncMock(side_effect=lambda x: x.upper())

        with patch(
            "app.core.ai_client.get_shared_http_session",
            AsyncMock(return_value=mock_session),
        ):
            content, _ = await service.call_with_fallback(
                messages=[{"role": "user", "content": "hi"}],
                model_type=ModelType.TEXT_GENERATION,
                post_process=custom_post,
            )
        assert content == "HELLO"

    async def test_call_with_fallback_by_model_id(self, ai_client_service):
        service, repo, security = ai_client_service
        model = _make_model()
        repo.get_by_id = AsyncMock(return_value=model)
        security.get_decrypted_api_key = AsyncMock(return_value="test-key")

        mock_resp = _FakeResponse(
            status=200,
            text='{"choices": [{"message": {"content": "By ID"}}]}',
        )
        mock_session = _make_mock_session(mock_resp)

        with patch(
            "app.core.ai_client.get_shared_http_session",
            AsyncMock(return_value=mock_session),
        ):
            content, returned_model = await service.call_with_fallback(
                messages=[{"role": "user", "content": "hi"}],
                model_id=42,
            )
        assert content == "By ID"

    async def test_call_with_fallback_no_params_raises(self, ai_client_service):
        from app.core.exceptions import ValidationError

        service, _, _ = ai_client_service
        with pytest.raises(ValidationError, match="required"):
            await service.call_with_fallback(
                messages=[{"role": "user", "content": "hi"}],
            )
