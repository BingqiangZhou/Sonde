"""Auth API routes（Phase B 恢复，契约见 backend/docs/AUTHENTICATION.md）。

变化点：
- register 受 REGISTRATION_OPEN 控制（默认 false → 403）
- forgot-password / reset-password 首版 501（管理员经面板/CLI 重置）
- login/register 挂限流
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.core.config import get_settings
from app.core.rate_limit import limiter
from app.domains.user.dependencies import (
    get_authentication_service,
    get_current_user,
)
from app.domains.user.schemas import (
    LoginRequest,
    LogoutRequest,
    RefreshTokenRequest,
    RegisterRequest,
    Token,
    UserResponse,
)
from app.domains.user.service import AuthenticationService


logger = logging.getLogger(__name__)

router = APIRouter()


def _client_ip(request: Request) -> str | None:
    return request.client.host if request.client else None


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def register(
    request: Request,
    register_data: RegisterRequest,
    auth_service: AuthenticationService = Depends(get_authentication_service),
) -> Any:
    """注册新用户并直接返回 token 对；REGISTRATION_OPEN=false 时 403。"""
    settings = get_settings()
    if not settings.REGISTRATION_OPEN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Registration is closed on this server. Contact the administrator.",
        )

    user = await auth_service.register_user(
        email=register_data.email,
        password=register_data.password,
        username=register_data.username,
    )
    token_data = await auth_service.create_user_session(
        user=user,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
        remember_me=register_data.remember_me,
    )
    return Token(**token_data)


@router.post("/login", response_model=Token)
@limiter.limit("10/minute")
async def login(
    request: Request,
    login_data: LoginRequest,
    auth_service: AuthenticationService = Depends(get_authentication_service),
) -> Any:
    """Login with email/username and password."""
    identifier = login_data.username or str(login_data.email_or_username or "")
    user = await auth_service.authenticate_user(
        email_or_username=identifier,
        password=login_data.password,
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    token_data = await auth_service.create_user_session(
        user=user,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
        remember_me=login_data.remember_me,
    )
    return Token(**token_data)


@router.post("/refresh", response_model=Token)
async def refresh_token(
    refresh_data: RefreshTokenRequest,
    auth_service: AuthenticationService = Depends(get_authentication_service),
) -> Any:
    """滑动会话刷新：返回新的 access/refresh 对（旧 refresh 失效）。"""
    token_data = await auth_service.refresh_access_token(
        refresh_token=refresh_data.refresh_token,
    )
    return Token(**token_data)


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: Any = Depends(get_current_user),
) -> Any:
    """Get current user information."""
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        username=current_user.username,
        account_name=current_user.account_name,
        is_active=current_user.is_active,
        is_superuser=current_user.is_superuser,
        is_verified=current_user.is_verified,
        avatar_url=current_user.avatar_url,
        created_at=current_user.created_at,
    )


@router.post("/logout", status_code=status.HTTP_200_OK)
async def logout(
    logout_data: LogoutRequest,
    current_user: Any = Depends(get_current_user),
    auth_service: AuthenticationService = Depends(get_authentication_service),
) -> Any:
    """Logout current user（带 refresh_token 登出单会话，否则全部）。"""
    if logout_data.refresh_token:
        await auth_service.logout_user(logout_data.refresh_token)
    else:
        await auth_service.logout_all_sessions(current_user.id)
    return {"message": "Successfully logged out"}


@router.post("/logout-all", status_code=status.HTTP_200_OK)
async def logout_all(
    current_user: Any = Depends(get_current_user),
    auth_service: AuthenticationService = Depends(get_authentication_service),
) -> Any:
    """Logout from all devices."""
    await auth_service.logout_all_sessions(current_user.id)
    return {"message": "Successfully logged out from all devices"}


@router.post("/forgot-password")
async def forgot_password() -> Any:
    """首版未接邮件系统：走管理员重置。"""
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Password reset via email is not available. Contact the administrator.",
    )


@router.post("/reset-password")
async def reset_password() -> Any:
    """首版未接邮件系统：走管理员重置。"""
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Password reset via email is not available. Contact the administrator.",
    )
