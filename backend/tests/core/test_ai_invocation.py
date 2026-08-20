"""Tests for app.domains.ai.invocation module.

Tests call_ai_api and call_ai_api_with_retry.
"""

from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.domains.ai.invocation import (
    RetryableAIModelError,
    call_ai_api,
    call_ai_api_with_retry,
    is_retryable_http_status,
    looks_like_html_error_page,
)


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
            "app.domains.ai.invocation.get_shared_http_session",
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
                "app.domains.ai.invocation.get_shared_http_session",
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
                "app.domains.ai.invocation.get_shared_http_session",
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
                "app.domains.ai.invocation.get_shared_http_session",
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

        with patch("app.domains.ai.invocation.settings") as mock_settings:
            mock_settings.AI_CLIENT_MAX_PROMPT_LENGTH = 50
            with patch(
                "app.domains.ai.invocation.get_shared_http_session",
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
            "app.domains.ai.invocation.get_shared_http_session",
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
                "app.domains.ai.invocation.get_shared_http_session",
                AsyncMock(return_value=mock_session),
            ),
            patch("app.domains.ai.invocation.settings") as mock_settings,
        ):
            mock_settings.AI_CLIENT_MAX_RETRIES = 3
            mock_settings.AI_CLIENT_BASE_DELAY = 0
            mock_settings.AI_CLIENT_MAX_PROMPT_LENGTH = 1000000
            with patch("app.domains.ai.invocation.asyncio.sleep", AsyncMock()):
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
                "app.domains.ai.invocation.get_shared_http_session",
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
