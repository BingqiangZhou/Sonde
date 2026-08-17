"""Tests for API key authentication in single-user mode."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException, Request


def _request_with_headers(headers: list[tuple[bytes, bytes]]) -> Request:
    return Request(scope={"type": "http", "headers": headers})


class TestApiKeyAuth:
    """API key validation tests."""

    async def test_no_key_returns_401_when_configured(self):
        """Test that missing API key returns 401 when API_KEY is configured."""
        mock_settings = MagicMock()
        mock_settings.API_KEY = "configured-key"

        with patch("app.core.auth.get_settings", return_value=mock_settings):
            from app.core.auth import require_api_key

            request = Request(scope={"type": "http", "headers": []})
            with pytest.raises(HTTPException) as exc_info:
                await require_api_key(request)
            assert exc_info.value.status_code == 401
            assert "Authentication required" in exc_info.value.detail

    async def test_wrong_key_returns_401(self):
        """Test that wrong API key returns 401."""
        mock_settings = MagicMock()
        mock_settings.API_KEY = "correct-key"

        with patch("app.core.auth.get_settings", return_value=mock_settings):
            from app.core.auth import require_api_key

            headers = [(b"authorization", b"Bearer wrong-key")]
            scope = {"type": "http", "headers": headers}
            request = Request(scope=scope)

            with pytest.raises(HTTPException) as exc_info:
                await require_api_key(request)
            assert exc_info.value.status_code == 401
            assert "Invalid API key" in exc_info.value.detail

    async def test_correct_bearer_key_returns_user_id(self):
        """Test that correct Bearer token returns user ID."""
        mock_settings = MagicMock()
        mock_settings.API_KEY = "my-secret-key"

        with patch("app.core.auth.get_settings", return_value=mock_settings):
            from app.core.auth import require_api_key

            headers = [(b"authorization", b"Bearer my-secret-key")]
            scope = {"type": "http", "headers": headers}
            request = Request(scope=scope)

            user_id = await require_api_key(request)
            assert user_id == 1

    async def test_x_api_key_header_works(self):
        """Test that X-API-Key header works."""
        mock_settings = MagicMock()
        mock_settings.API_KEY = "my-secret-key"

        with patch("app.core.auth.get_settings", return_value=mock_settings):
            from app.core.auth import require_api_key

            headers = [(b"x-api-key", b"my-secret-key")]
            scope = {"type": "http", "headers": headers}
            request = Request(scope=scope)

            user_id = await require_api_key(request)
            assert user_id == 1

    async def test_no_key_allowed_when_api_key_empty(self):
        """Test that requests are allowed when API_KEY is empty (dev mode)."""
        mock_settings = MagicMock()
        mock_settings.API_KEY = ""

        with patch("app.core.auth.get_settings", return_value=mock_settings):
            from app.core.auth import require_api_key

            request = Request(scope={"type": "http", "headers": []})
            user_id = await require_api_key(request)
            assert user_id == 1

    def test_extract_api_key_from_bearer(self):
        """Test _extract_api_key extracts Bearer token correctly."""
        from app.core.auth import _extract_api_key

        headers = [(b"authorization", b"Bearer test-key")]
        scope = {"type": "http", "headers": headers}
        request = Request(scope=scope)

        assert _extract_api_key(request) == "test-key"

    def test_extract_api_key_from_x_api_key(self):
        """Test _extract_api_key extracts X-API-Key correctly."""
        from app.core.auth import _extract_api_key

        headers = [(b"x-api-key", b"test-key")]
        scope = {"type": "http", "headers": headers}
        request = Request(scope=scope)

        assert _extract_api_key(request) == "test-key"

    def test_extract_api_key_returns_none_when_missing(self):
        """Test _extract_api_key returns None when no key present."""
        from app.core.auth import _extract_api_key

        request = Request(scope={"type": "http", "headers": []})
        assert _extract_api_key(request) is None


class TestJwtDualModeAuth:
    """JWT access tokens resolve to real user IDs alongside API-key mode."""

    def _mock_settings(self, api_key: str) -> MagicMock:
        mock_settings = MagicMock()
        mock_settings.API_KEY = api_key
        return mock_settings

    async def test_valid_jwt_resolves_real_user_id(self):
        from app.domains.auth.security import issue_tokens

        with patch(
            "app.core.auth.get_settings",
            return_value=self._mock_settings("server-key"),
        ):
            from app.core.auth import require_api_key

            token = issue_tokens(42).access_token
            request = _request_with_headers(
                [(b"authorization", f"Bearer {token}".encode())]
            )
            assert await require_api_key(request) == 42

    async def test_invalid_jwt_falls_through_to_api_key_check(self):
        with patch(
            "app.core.auth.get_settings",
            return_value=self._mock_settings("server-key"),
        ):
            from app.core.auth import require_api_key

            # Garbage Bearer token: JWT parsing fails, API key mismatch -> 401.
            request = _request_with_headers([(b"authorization", b"Bearer garbage")])
            with pytest.raises(HTTPException) as exc_info:
                await require_api_key(request)
            assert exc_info.value.status_code == 401

    async def test_api_key_still_returns_single_user_id(self):
        with patch(
            "app.core.auth.get_settings",
            return_value=self._mock_settings("server-key"),
        ):
            from app.core.auth import require_api_key

            request = _request_with_headers([(b"authorization", b"Bearer server-key")])
            assert await require_api_key(request) == 1

    async def test_refresh_token_does_not_authenticate_api_requests(self):
        from app.domains.auth.security import issue_tokens

        with patch(
            "app.core.auth.get_settings",
            return_value=self._mock_settings("server-key"),
        ):
            from app.core.auth import require_api_key

            token = issue_tokens(7).refresh_token
            request = _request_with_headers(
                [(b"authorization", f"Bearer {token}".encode())]
            )
            with pytest.raises(HTTPException) as exc_info:
                await require_api_key(request)
            assert exc_info.value.status_code == 401

    async def test_dev_mode_without_api_key_allows_all(self):
        with patch(
            "app.core.auth.get_settings",
            return_value=self._mock_settings(""),
        ):
            from app.core.auth import require_api_key

            request = _request_with_headers([])
            assert await require_api_key(request) == 1
