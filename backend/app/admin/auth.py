"""Admin authentication — API key based."""

import hashlib
import hmac
import logging
import secrets

from fastapi import Cookie, HTTPException, Request, status

from app.core.auth import extract_api_key
from app.core.config import get_settings


logger = logging.getLogger(__name__)


def _compute_session_hash(api_key: str) -> str:
    """Compute HMAC hash of API key for cookie storage."""
    settings = get_settings()
    return hmac.new(
        settings.get_secret_key().encode(), api_key.encode(), hashlib.sha256
    ).hexdigest()


class AdminAuthRequired:
    async def __call__(
        self,
        request: Request,
        admin_session: str | None = Cookie(None),
    ) -> int:
        settings = get_settings()

        if not settings.API_KEY:
            return 1

        # Header-based auth: compare API key directly
        header_key = extract_api_key(request)
        if header_key is not None:
            if secrets.compare_digest(header_key, settings.API_KEY):
                return 1
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key",
            )

        # Cookie-based auth: CSRF defence — browsers always send Origin on
        # cross-site POSTs; require it to match the request host when present.
        # (Non-browser clients without a browser-issued cookie are unaffected.)
        origin = request.headers.get("Origin")
        if origin:
            origin_host = origin.split("://", 1)[-1].split("/", 1)[0]
            request_host = request.headers.get("Host", "")
            if origin_host != request_host:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Cross-origin admin session usage is not allowed",
                )

        # Cookie-based auth: compare HMAC hash
        if admin_session is not None:
            expected_hash = _compute_session_hash(settings.API_KEY)
            if secrets.compare_digest(admin_session, expected_hash):
                return 1
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid session",
            )

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )


admin_required = AdminAuthRequired()
