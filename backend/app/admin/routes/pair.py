"""Admin pairing page: QR code for app onboarding (host + API key)."""

import io
from urllib.parse import urlencode

import segno
from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse

from app.admin.auth import admin_required
from app.admin.routes._shared import get_templates, render_admin_template
from app.core.config import get_settings


router = APIRouter()
templates = get_templates()


def _default_host(request: Request) -> str:
    """Derive ``scheme://netloc`` from the incoming request as a host guess."""
    return f"{request.url.scheme}://{request.url.netloc}"


def _connect_uri(host: str, api_key: str) -> str:
    """Build the deep link the app expects from the scanned QR payload."""
    return f"sonde://connect?{urlencode({'host': host, 'key': api_key})}"


def _qr_svg(content: str) -> str:
    """Render the QR payload as an inline SVG string."""
    buffer = io.BytesIO()
    segno.make(content, error="m").save(buffer, kind="svg", scale=6, border=2)
    return buffer.getvalue().decode("utf-8")


@router.get("/pair", response_class=HTMLResponse)
async def pair_page(
    request: Request,
    host: str | None = None,
    _admin: int = Depends(admin_required),
):
    """Display the app pairing QR (host confirmable via query param)."""
    settings = get_settings()
    resolved_host = (host or _default_host(request)).strip().rstrip("/")
    connect_uri = _connect_uri(resolved_host, settings.API_KEY or "")
    return render_admin_template(
        templates=templates,
        template_name="pair.html",
        request=request,
        host=resolved_host,
        connect_uri=connect_uri,
        qr_svg=_qr_svg(connect_uri),
        has_api_key=bool(settings.API_KEY),
    )
