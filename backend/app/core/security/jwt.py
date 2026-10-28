"""JWT token creation and verification (HS256 + SECRET_KEY).

自 v0 历史实现恢复（2026-04 简化时删除），按 Phase B 契约精简：
仅保留 access/refresh 令牌的签发与校验，FastAPI 依赖在 `app.core.auth`。
"""

from __future__ import annotations

import logging
import time
import uuid
from datetime import timedelta

import jwt as pyjwt
from fastapi import HTTPException, status
from jwt.exceptions import InvalidTokenError as JWTError

from app.core.config import settings


logger = logging.getLogger(__name__)

UserId = int


async def create_access_token(
    data: dict,
    expires_delta: timedelta | None = None,
) -> str:
    """Create JWT access token（默认 ACCESS_TOKEN_EXPIRE_MINUTES=30 分钟）。"""
    custom_minutes = expires_delta.total_seconds() / 60 if expires_delta else None

    expire_minutes_val = custom_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    now_ts = int(time.time())
    claims = {
        "exp": now_ts + int(expire_minutes_val * 60),
        "iat": now_ts,
        "jti": str(uuid.uuid4()),
    }
    claims.update(data or {})

    return pyjwt.encode(claims, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


async def create_refresh_token(
    data: dict,
    expires_delta: timedelta | None = None,
) -> str:
    """Create JWT refresh token（默认 REFRESH_TOKEN_EXPIRE_DAYS=7 天，type=refresh）。"""
    if expires_delta is None:
        expires_delta = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    expire_seconds = int(expires_delta.total_seconds())
    now_ts = int(time.time())
    claims = {
        "exp": now_ts + expire_seconds,
        "iat": now_ts,
        "type": "refresh",
        "jti": str(uuid.uuid4()),
    }
    claims.update(data or {})

    return pyjwt.encode(claims, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


async def verify_token(token: str, token_type: str = "access") -> dict:
    """Verify and decode JWT token；类型不符/过期/签名无效 → 401。"""
    try:
        payload = pyjwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )

        if "type" in payload and payload["type"] != token_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type",
            )

        exp = payload.get("exp")
        if exp is None or time.time() > exp:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired",
            )

        return payload

    except JWTError as e:
        logger.warning("JWT decode failed: %s: %s", type(e).__name__, e)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        ) from e


def get_user_id_from_token(token_payload: dict) -> UserId:
    """从 payload 的 sub 声明提取 int user_id；缺失/非法抛 ValueError。"""
    sub = token_payload.get("sub")
    if sub is None:
        raise KeyError("Token payload missing 'sub' claim")
    try:
        return int(sub)
    except (ValueError, TypeError) as e:
        raise ValueError(f"Token 'sub' claim '{sub}' is not a valid integer") from e
