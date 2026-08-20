"""Auth domain HTTP routes (JWT multi-user flow).

Prefix: ``/api/v1/auth`` — matches the Flutter ``AuthRepositoryImpl`` paths.
"""

from datetime import UTC, datetime

import jwt as pyjwt
from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency
from app.core.exceptions import UnauthorizedError
from app.core.rate_limit import limiter
from app.domains.auth.repositories.user_repository import UserRepository
from app.domains.auth.schemas import (
    AuthResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    UpdateProfileRequest,
    UserResponse,
)
from app.domains.auth.security import TokenBundle, decode_token
from app.domains.auth.services.auth_service import AuthService


router = APIRouter()


def get_user_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> UserRepository:
    return UserRepository(db)


def get_auth_service(
    users: UserRepository = Depends(get_user_repository),
) -> AuthService:
    return AuthService(users)


async def get_current_user_id(request: Request) -> int:
    """JWT-only dependency for endpoints about the authenticated user."""
    authorization = request.headers.get("Authorization", "")
    if authorization.startswith("Bearer "):
        try:
            payload = decode_token(authorization[7:], "access")
            return int(payload["sub"])
        except (pyjwt.InvalidTokenError, KeyError, ValueError):
            pass
    raise UnauthorizedError(
        "Not authenticated",
        details={
            "message_en": "Please log in first",
            "message_zh": "请先登录",
        },
    )


def _auth_response(tokens: TokenBundle) -> AuthResponse:
    return AuthResponse(
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        token_type=tokens.token_type,
        expires_in=tokens.expires_in,
        expires_at=tokens.expires_at,
        server_time=datetime.now(UTC),
        session_id=tokens.session_id,
    )


@router.post("/register", response_model=AuthResponse, status_code=201)
@limiter.limit("5/minute")
async def register(
    request: Request,
    payload: RegisterRequest,
    service: AuthService = Depends(get_auth_service),
) -> AuthResponse:
    """Register with email + password only; the name is system-generated."""
    _, tokens = await service.register(payload.email, payload.password)
    return _auth_response(tokens)


@router.post("/login", response_model=AuthResponse)
@limiter.limit("5/minute")
async def login(
    request: Request,
    payload: LoginRequest,
    service: AuthService = Depends(get_auth_service),
) -> AuthResponse:
    _, tokens = await service.login(payload.email_or_username, payload.password)
    return _auth_response(tokens)


@router.post("/refresh", response_model=AuthResponse)
@limiter.limit("10/minute")
async def refresh(
    request: Request,
    payload: RefreshRequest,
    service: AuthService = Depends(get_auth_service),
) -> AuthResponse:
    _, tokens = await service.refresh(payload.refresh_token)
    return _auth_response(tokens)


@router.post("/logout")
async def logout(
    payload: RefreshRequest | None = None,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    """Revoke the presented refresh token; clearing the rest is client-side."""
    await service.logout(payload.refresh_token if payload else None)
    return {"detail": "Logged out"}


@router.get("/me", response_model=UserResponse)
async def read_current_user(
    user_id: int = Depends(get_current_user_id),
    service: AuthService = Depends(get_auth_service),
) -> UserResponse:
    user = await service.get_user(user_id)
    return UserResponse.from_user(user)


@router.patch("/me", response_model=UserResponse)
async def update_current_user(
    payload: UpdateProfileRequest,
    user_id: int = Depends(get_current_user_id),
    service: AuthService = Depends(get_auth_service),
) -> UserResponse:
    user = await service.update_username(user_id, payload.username)
    return UserResponse.from_user(user)
