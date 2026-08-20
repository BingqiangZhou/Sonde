"""Authentication and request-level FastAPI dependencies.

Dual mode:
- Single-user API key: Authorization: Bearer <API key> or X-API-Key header.
  User ID is hardcoded to 1.
- Multi-user JWT: Authorization: Bearer <access token> issued by
  /api/v1/auth/* resolves to the real user ID.
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

# Hardcoded single-user ID
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


def _user_id_from_bearer(token: str) -> int | None:
    """Resolve a JWT access token to its user ID, or None if invalid."""
    from app.domains.auth.security import user_id_from_token

    return user_id_from_token(token, "access")


async def require_api_key(request: Request) -> int:
    """Authenticate the request and return the acting user ID.

    Resolution order: valid JWT access token first (real multi-user ID),
    then the configured API key (single-user ID 1), then the dev bypass when
    no API key is configured. Raises HTTPException 401 otherwise.
    """
    settings = get_settings()

    authorization = request.headers.get("Authorization", "")
    if authorization.startswith("Bearer "):
        user_id = _user_id_from_bearer(authorization[7:])
        if user_id is not None:
            return user_id

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


async def get_redis_client():
    """Provide the shared Redis helper (process-level singleton)."""
    from app.core.redis import get_shared_redis

    return get_shared_redis()
