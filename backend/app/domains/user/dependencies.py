"""User API dependency providers."""

from __future__ import annotations

from collections.abc import AsyncGenerator

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency, require_user
from app.domains.user.models import User
from app.domains.user.repository import UserRepository
from app.domains.user.service import AuthenticationService


async def get_authentication_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> AsyncGenerator[AuthenticationService, None]:
    yield AuthenticationService(db)


async def get_user_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> AsyncGenerator[UserRepository, None]:
    yield UserRepository(db)


async def get_current_user(
    user_id: int = Depends(require_user),
    repo: UserRepository = Depends(get_user_repository),
) -> User:
    """当前登录用户（404 防枚举：不存在/停用统一 401 语义由调用方处理）。"""
    user = await repo.get_by_id(user_id)
    if user is None or not user.is_active:
        from fastapi import HTTPException, status

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User inactive or not found",
        )
    return user
