"""Authentication and request-level FastAPI dependencies.

多用户模式（Phase B）：
- require_user：JWT access token → user_id；X-API-Key/Bearer 命中 settings.API_KEY
  时映射为运维通道（第一个活跃超管）；开发态（DEBUG + 未配置 API_KEY）无凭据放行 user 1。
- require_api_key：单管理员口令（供 Jinja2 管理面板与运维脚本），不再用于业务路由。
"""

from __future__ import annotations

import logging
import secrets
from collections.abc import AsyncGenerator

from fastapi import HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.database import get_db_session


logger = logging.getLogger(__name__)

# Hardcoded single-user ID
SINGLE_USER_ID = 1


# ── Auth dependency ──────────────────────────────────────────────────────────


def _extract_api_key(request: Request) -> str | None:
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
    """Validate API key and return the hardcoded single-user ID.

    Raises HTTPException 401 if the key is missing or invalid.
    """
    settings = get_settings()

    # If no API_KEY configured (development), allow all requests
    if not settings.API_KEY:
        return SINGLE_USER_ID

    api_key = _extract_api_key(request)
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


# ── Multi-user JWT dependency（Phase B）───────────────────────────────────────


async def _resolve_ops_user_id() -> int:
    """运维 API Key 通道映射到的用户：第一个活跃超管。

    无超管时 503（提示先建号）——避免落回不存在的 user_id 破坏外键。
    """
    from sqlalchemy import select

    from app.domains.user.models import User, UserStatus

    async for db in get_db_session():
        result = await db.execute(
            select(User.id)
            .where(User.is_superuser.is_(True), User.status == UserStatus.ACTIVE)
            .order_by(User.id)
            .limit(1)
        )
        row = result.scalar_one_or_none()
        break
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Ops API key channel requires a superuser; create one first (CLI or admin panel)",
        )
    return int(row)


async def require_user(request: Request) -> int:
    """多用户鉴权：JWT access token → user_id。

    通道优先级：
    1. X-API-Key / Bearer 与 settings.API_KEY 恒时相等 → 运维通道（映射到第一个超管）；
    2. 其余按 JWT access token 校验（401 on missing/invalid/expired）；
    3. 开发便利：ENVIRONMENT=development 且 DEBUG 且未配置 API_KEY 且无凭据 → user 1。
    """
    settings = get_settings()
    credentials = _extract_api_key(request)

    # 运维通道：API Key 命中
    if credentials and settings.API_KEY and secrets.compare_digest(
        credentials, settings.API_KEY
    ):
        return await _resolve_ops_user_id()

    # 开发放行（与旧 require_api_key 的空 API_KEY 行为一致）
    if (
        credentials is None
        and not settings.API_KEY
        and settings.ENVIRONMENT == "development"
        and settings.DEBUG
    ):
        return SINGLE_USER_ID

    from app.core.security.jwt import get_user_id_from_token, verify_token

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    try:
        payload = await verify_token(credentials, token_type="access")
        return get_user_id_from_token(payload)
    except (KeyError, ValueError) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {e}",
        ) from e


# ── Base dependencies ────────────────────────────────────────────────────────


async def get_db_session_dependency() -> AsyncGenerator[AsyncSession, None]:
    """Provide the request-scoped DB session through the provider layer."""
    async for db in get_db_session():
        yield db


async def get_redis_client():
    """Provide the shared Redis helper (process-level singleton)."""
    from app.core.redis import get_shared_redis

    return get_shared_redis()


def get_settings_dependency() -> Settings:
    """Provide cached application settings."""
    return get_settings()
