"""Pairing page tests: connect URI building and QR rendering."""

from unittest.mock import MagicMock, patch

import pytest

from app.admin.routes.pair import _connect_uri, _qr_svg


class TestConnectUri:
    def test_builds_uri_with_urlencoded_params(self):
        uri = _connect_uri("http://192.168.1.5:8000", "sk-abc123")
        assert (
            uri == "sonde://connect?host=http%3A%2F%2F192.168.1.5%3A8000&key=sk-abc123"
        )

    def test_empty_key_still_builds_uri(self):
        uri = _connect_uri("http://localhost:8000", "")
        assert uri.endswith("key=")


class TestQrSvg:
    def test_renders_inline_svg_containing_payload(self):
        svg = _qr_svg("sonde://connect?host=x&key=y")
        assert svg.startswith("<?xml")
        assert "<svg" in svg
        assert svg.rstrip().endswith("</svg>")


@pytest.mark.asyncio
async def test_pair_page_requires_admin_auth():
    """The pairing page is guarded by admin_required (QR holds the API key)."""
    from httpx import ASGITransport, AsyncClient

    from app.main import app

    with patch("app.core.rate_limit.limiter"):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/api/v1/admin/pair")
    # Unauthenticated HTML pages redirect to the admin login (303), and the
    # QR (which carries the API key) must not leak in the redirect response.
    assert response.status_code == 303
    assert "test-key" not in response.text


@pytest.mark.asyncio
async def test_pair_page_renders_qr_for_admin():
    from httpx import ASGITransport, AsyncClient

    from app.main import app

    mock_settings = MagicMock()
    mock_settings.API_KEY = "test-key-123"

    with (
        patch("app.admin.auth.get_settings", return_value=mock_settings),
        patch("app.admin.routes.pair.get_settings", return_value=mock_settings),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport,
            base_url="http://test",
            headers={"X-API-Key": "test-key-123"},
        ) as client:
            response = await client.get(
                "/api/v1/admin/pair",
                params={"host": "http://192.168.1.5:8000"},
            )

    assert response.status_code == 200
    assert "<svg" in response.text
    assert "192.168.1.5" in response.text
    # The raw connect string shown for manual entry carries the API key.
    assert "test-key-123" in response.text
