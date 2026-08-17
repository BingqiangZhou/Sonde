"""User persistence for the auth domain."""

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.auth.models import User


class UserRepository:
    """Async repository over the ``users`` table."""

    def __init__(self, db: AsyncSession):
        self._db = db

    async def get_by_id(self, user_id: int) -> User | None:
        result = await self._db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        result = await self._db.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

    async def get_by_username(self, username: str) -> User | None:
        result = await self._db.execute(select(User).where(User.username == username))
        return result.scalar_one_or_none()

    async def create(self, *, email: str, username: str, hashed_password: str) -> User:
        now = datetime.now(UTC)
        user = User(
            email=email,
            username=username,
            hashed_password=hashed_password,
            status="active",
            is_superuser=False,
            is_verified=True,  # no email infrastructure; accounts start verified
            last_login_at=now,
            created_at=now,
            updated_at=now,
        )
        self._db.add(user)
        await self._db.commit()
        await self._db.refresh(user)
        return user

    async def save(self, user: User) -> User:
        await self._db.commit()
        await self._db.refresh(user)
        return user
