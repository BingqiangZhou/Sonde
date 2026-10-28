"""Authentication service（Phase B 自 v0 历史精简恢复）。

契约：backend/docs/AUTHENTICATION.md（register/login/refresh/me/logout/logout-all）。
不做邮件流：forgot/reset-password 由路由层直接 501（管理员经面板/CLI 重置）。
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import (
    BadRequestError,
    ConflictError,
    UnauthorizedError,
)
from app.core.security import (
    create_access_token,
    create_refresh_token,
    get_password_hash,
    verify_password,
    verify_token,
)
from app.domains.user.models import User, UserStatus
from app.domains.user.repository import UserRepository


logger = logging.getLogger(__name__)


class AuthenticationService:
    """Service for handling authentication operations."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = UserRepository(db)

    # -- Registration / Login ------------------------------------------------

    async def register_user(
        self,
        email: str,
        password: str,
        username: str | None = None,
        is_superuser: bool = False,
    ) -> User:
        """Register a new user.

        Raises:
            ConflictError: email/username 已存在
            BadRequestError: 密码弱于 8 位
        """
        if len(password) < 8:
            raise BadRequestError("Password must be at least 8 characters")

        if await self.repo.get_by_email(email):
            raise ConflictError("Email already registered")
        if username and await self.repo.get_by_username(username):
            raise ConflictError("Username already taken")

        user = await self.repo.create(
            email=email, password=password, username=username, is_superuser=is_superuser
        )
        await self.db.commit()
        logger.info("Registered user id=%s email=%s", user.id, user.email)
        return user

    async def authenticate_user(
        self, email_or_username: str, password: str
    ) -> User | None:
        """邮箱/用户名 + 密码登录；恒时比较（bcrypt），失败统一返回 None。"""
        user = await self.repo.get_by_email_or_username(email_or_username)
        if user is None:
            # 恒时：对固定哈希跑一次校验，避免用户不存在时快速返回
            verify_password(password, DUMMY_HASH)
            return None
        if not verify_password(password, user.hashed_password):
            return None
        if user.status != UserStatus.ACTIVE:
            logger.warning("Login attempt for inactive user id=%s", user.id)
            return None
        return user

    # -- Sessions / tokens ----------------------------------------------------

    async def create_user_session(
        self,
        user: User,
        ip_address: str | None = None,
        user_agent: str | None = None,
        remember_me: bool = False,
    ) -> dict[str, Any]:
        """登录/注册成功后签发 token 对并落 user_sessions 行。"""
        token_data = {"sub": str(user.id), "email": user.email}
        access_token = await create_access_token(token_data)
        refresh_token = await create_refresh_token(token_data)

        await self.repo.create_session(
            user_id=user.id,
            session_token=str(uuid.uuid4()),
            refresh_token=refresh_token,
            ip_address=ip_address,
            user_agent=user_agent,
            device_info={"user_agent": user_agent, "ip_address": ip_address},
            remember_me=remember_me,
        )
        await self.repo.update_last_login(user.id)
        await self.db.commit()

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        }

    async def refresh_access_token(self, refresh_token: str) -> dict[str, Any]:
        """滑动会话：校验 refresh token（DB 会话 + JWT 双重），签发新对。"""
        payload = await verify_token(refresh_token, token_type="refresh")

        session = await self.repo.get_active_session_by_refresh_token(refresh_token)
        if session is None:
            raise UnauthorizedError("Session revoked or expired")

        user = await self.repo.get_by_id(int(payload["sub"]))
        if user is None or user.status != UserStatus.ACTIVE:
            raise UnauthorizedError("User inactive or not found")

        token_data = {"sub": str(user.id), "email": user.email}
        new_access = await create_access_token(token_data)
        new_refresh = await create_refresh_token(token_data)

        # 轮换 refresh token：旧会话吊销、新会话落库
        await self.repo.deactivate_session_by_refresh_token(refresh_token)
        await self.repo.create_session(
            user_id=user.id,
            session_token=str(uuid.uuid4()),
            refresh_token=new_refresh,
        )
        await self.db.commit()

        return {
            "access_token": new_access,
            "refresh_token": new_refresh,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        }

    async def logout_user(self, refresh_token: str) -> bool:
        """登出单个会话。"""
        ok = await self.repo.deactivate_session_by_refresh_token(refresh_token)
        await self.db.commit()
        return ok

    async def logout_all_sessions(self, user_id: int) -> int:
        """登出该用户全部会话。"""
        await self.repo.deactivate_all_sessions(user_id)
        await self.db.commit()
        return 0

    async def get_user(self, user_id: int) -> User | None:
        return await self.repo.get_by_id(user_id)

    # -- Admin operations（面板/CLI 复用） ------------------------------------

    async def admin_reset_password(self, user_id: int, new_password: str) -> User:
        """管理员重置密码并吊销全部会话。"""
        if len(new_password) < 8:
            raise BadRequestError("Password must be at least 8 characters")
        user = await self.repo.update_password(user_id, new_password)
        if user is None:
            from app.core.exceptions import NotFoundError

            raise NotFoundError("User not found")
        await self.repo.deactivate_all_sessions(user_id)
        await self.db.commit()
        return user

    async def admin_create_user(
        self, email: str, password: str, username: str | None = None, is_superuser: bool = False
    ) -> User:
        """管理员建号（不受 REGISTRATION_OPEN 限制）。"""
        return await self.register_user(email, password, username, is_superuser)


# 恒时比较用的占位哈希（登录失败路径）
DUMMY_HASH = get_password_hash("dummy-password-for-timing")
