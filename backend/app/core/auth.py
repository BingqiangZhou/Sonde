"""Authentication and request-level FastAPI dependencies.

Single API-key mode: Authorization: Bearer <API key> or X-API-Key header.
Every authenticated request acts as the fixed single operator user
(SINGLE_USER_ID). The JWT multi-user flow was removed with the auth domain
in the server-pipeline restructure.
"""

from __future__ import annotations

import logging
import secrets
from collections.abc import AsyncGenerator

from fastapi import HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db_session


logger = logging.getLogger(__name__)

# Fixed operator user id; the users table row is seeded at startup.
SINGLE_USER_ID = 1


# ── Auth dependency ──────────────────────────────────────────────────────────


def extract_api_key(request: Request) -> str | None:
    """Extract API key from Authorization: Bearer <key> or X-API-Key header."""
    authorization = request.headers.get("Authorization")
    if authorization:
        if authorization.startswith("Bearer "):
            return authorization[7:]
        return authorization

    x_api_key = request.headers.get("X-API-Key")
    if x_api_key:
        return x_api_key

    return None


async def require_api_key(request: Request) -> int:
    """Authenticate the request and return the acting user ID.

    Resolution order: the configured API key (single operator user), then
    the dev bypass when no API key is configured. Raises HTTPException 401
    otherwise.
    """
    settings = get_settings()

    if not settings.API_KEY:
        # If no API_KEY configured (development), allow all requests
        return SINGLE_USER_ID

    api_key = extract_api_key(request)
    if api_key is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )

    if not secrets.compare_digest(api_key, settings.API_KEY):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )

    return SINGLE_USER_ID


# ── Base dependencies ────────────────────────────────────────────────────────


async def get_db_session_dependency() -> AsyncGenerator[AsyncSession, None]:
    """Provide the request-scoped DB session through the provider layer."""
    async for db in get_db_session():
        yield db
