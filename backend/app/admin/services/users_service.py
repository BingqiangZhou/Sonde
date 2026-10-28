"""Admin users management service（Phase B：建号/重置/停启用/超管）。"""

from __future__ import annotations

import logging

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.user.models import User, UserStatus
from app.domains.user.repository import UserRepository


logger = logging.getLogger(__name__)


class AdminUsersService:
    """用户管理（管理面板用；REGISTRATION_OPEN 关闭时的建号通道）。"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = UserRepository(db)

    async def get_page_context(self, page: int = 1, per_page: int = 20) -> dict:
        total = (
            await self.db.execute(select(func.count()).select_from(User))
        ).scalar_one()
        users = (
            await self.db.execute(
                select(User).order_by(User.id).limit(per_page).offset((page - 1) * per_page)
            )
        ).scalars().all()

        return {
            "users": [
                {
                    "id": u.id,
                    "email": u.email,
                    "username": u.username,
                    "status": u.status,
                    "is_superuser": u.is_superuser,
                    "is_verified": u.is_verified,
                    "last_login_at": u.last_login_at,
                    "created_at": u.created_at,
                }
                for u in users
            ],
            "total": total,
            "page": page,
            "per_page": per_page,
            "pages": (total + per_page - 1) // per_page,
            "registration_open": (await self._registration_open()),
        }

    async def _registration_open(self) -> bool:
        from app.core.config import get_settings

        return get_settings().REGISTRATION_OPEN

    async def create_user(
        self,
        email: str,
        password: str,
        username: str | None = None,
        is_superuser: bool = False,
    ) -> User:
        from app.core.exceptions import ConflictError

        if await self.repo.get_by_email(email):
            raise ConflictError("Email already registered")
        if username and await self.repo.get_by_username(username):
            raise ConflictError("Username already taken")

        user = await self.repo.create(
            email=email, password=password, username=username, is_superuser=is_superuser
        )
        await self.db.commit()
        return user

    async def reset_password(self, user_id: int, new_password: str) -> User:
        """重置密码并吊销全部会话。"""
        from app.core.exceptions import BadRequestError, NotFoundError

        if len(new_password) < 8:
            raise BadRequestError("密码至少 8 位")
        user = await self.repo.update_password(user_id, new_password)
        if user is None:
            raise NotFoundError("User not found")
        await self.repo.deactivate_all_sessions(user_id)
        await self.db.commit()
        return user

    async def set_status(self, user_id: int, status: UserStatus) -> User:
        from app.core.exceptions import NotFoundError

        user = await self.repo.update_status(user_id, status)
        if user is None:
            raise NotFoundError("User not found")
        if status != UserStatus.ACTIVE:
            await self.repo.deactivate_all_sessions(user_id)
        await self.db.commit()
        return user

    async def toggle_active(self, user_id: int) -> User:
        user = await self.repo.get_by_id(user_id)
        if user is None:
            from app.core.exceptions import NotFoundError

            raise NotFoundError("User not found")
        new_status = (
            UserStatus.INACTIVE if user.status == UserStatus.ACTIVE else UserStatus.ACTIVE
        )
        return await self.set_status(user_id, new_status)

    async def set_superuser(self, user_id: int, value: bool) -> User:
        await self.db.execute(
            update(User).where(User.id == user_id).values(is_superuser=value)
        )
        await self.db.commit()
        user = await self.repo.get_by_id(user_id)
        if user is None:
            from app.core.exceptions import NotFoundError

            raise NotFoundError("User not found")
        return user
