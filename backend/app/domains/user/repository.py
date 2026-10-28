"""User repository（Phase B 自 v0 历史精简恢复：查询/建号/改密/会话）。"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security.password import get_password_hash
from app.domains.user.models import User, UserSession, UserStatus


class UserRepository:
    """User/UserSession data access layer."""

    def __init__(self, db: AsyncSession):
        self.db = db

    # -- User lookups -------------------------------------------------------

    async def get_by_id(self, user_id: int) -> User | None:
        result = await self.db.execute(select(User).filter(User.id == user_id))
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        result = await self.db.execute(
            select(User).filter(User.email == email.lower())
        )
        return result.scalar_one_or_none()

    async def get_by_username(self, username: str) -> User | None:
        result = await self.db.execute(
            select(User).filter(User.username == username)
        )
        return result.scalar_one_or_none()

    async def get_by_email_or_username(self, identifier: str) -> User | None:
        """邮箱（小写归一）或用户名查找。"""
        user = await self.get_by_email(identifier)
        if user is None:
            user = await self.get_by_username(identifier)
        return user

    async def get_first_superuser(self) -> User | None:
        result = await self.db.execute(
            select(User)
            .filter(User.is_superuser.is_(True), User.status == UserStatus.ACTIVE)
            .order_by(User.id)
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def list_users(self, limit: int = 100, offset: int = 0) -> list[User]:
        result = await self.db.execute(
            select(User).order_by(User.id).limit(limit).offset(offset)
        )
        return list(result.scalars().all())

    # -- User mutations -----------------------------------------------------

    async def create(
        self,
        email: str,
        password: str,
        username: str | None = None,
        is_superuser: bool = False,
    ) -> User:
        user = User(
            email=email.lower(),
            username=username,
            hashed_password=get_password_hash(password),
            status=UserStatus.ACTIVE,
            is_superuser=is_superuser,
            is_verified=True,
            settings={},
            preferences={},
        )
        self.db.add(user)
        await self.db.flush()
        return user

    async def update_password(self, user_id: int, new_password: str) -> User | None:
        await self.db.execute(
            update(User)
            .where(User.id == user_id)
            .values(hashed_password=get_password_hash(new_password))
        )
        return await self.get_by_id(user_id)

    async def update_status(self, user_id: int, status: UserStatus) -> User | None:
        await self.db.execute(
            update(User).where(User.id == user_id).values(status=status)
        )
        return await self.get_by_id(user_id)

    async def set_superuser(self, user_id: int, value: bool) -> User | None:
        await self.db.execute(
            update(User).where(User.id == user_id).values(is_superuser=value)
        )
        return await self.get_by_id(user_id)

    async def update_last_login(self, user_id: int) -> None:
        await self.db.execute(
            update(User)
            .where(User.id == user_id)
            .values(last_login_at=datetime.now(UTC))
        )

    async def deactivate_all_sessions(self, user_id: int) -> None:
        """改密/停用时吊销全部会话。"""
        await self.db.execute(
            update(UserSession)
            .where(UserSession.user_id == user_id, UserSession.is_active.is_(True))
            .values(is_active=False)
        )

    # -- Sessions -----------------------------------------------------------

    async def create_session(
        self,
        user_id: int,
        session_token: str,
        refresh_token: str,
        ip_address: str | None = None,
        user_agent: str | None = None,
        device_info: dict | None = None,
        remember_me: bool = False,
    ) -> UserSession:
        days = (
            settings.REFRESH_TOKEN_EXPIRE_DAYS * 4 if remember_me else settings.REFRESH_TOKEN_EXPIRE_DAYS
        )
        session = UserSession(
            user_id=user_id,
            session_token=session_token,
            refresh_token=refresh_token,
            ip_address=ip_address,
            user_agent=user_agent,
            device_info=device_info,
            expires_at=datetime.now(UTC) + timedelta(days=days),
        )
        self.db.add(session)
        await self.db.flush()
        return session

    async def get_active_session_by_refresh_token(
        self, refresh_token: str
    ) -> UserSession | None:
        result = await self.db.execute(
            select(UserSession).filter(
                UserSession.refresh_token == refresh_token,
                UserSession.is_active.is_(True),
            )
        )
        return result.scalar_one_or_none()

    async def deactivate_session_by_refresh_token(self, refresh_token: str) -> bool:
        result = await self.db.execute(
            update(UserSession)
            .where(
                UserSession.refresh_token == refresh_token,
                UserSession.is_active.is_(True),
            )
            .values(is_active=False)
        )
        return bool(result.rowcount)

    async def touch_session(self, session: UserSession) -> None:
        session.last_activity_at = datetime.now(UTC)
        await self.db.flush()

    async def cleanup_expired_sessions(self) -> int:
        result = await self.db.execute(
            delete(UserSession).where(
                UserSession.expires_at < datetime.now(UTC),
            )
        )
        return result.rowcount or 0
