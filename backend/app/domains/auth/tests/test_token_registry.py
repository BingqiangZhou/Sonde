"""Refresh-token registry and rotation tests (deterministic, no real redis)."""

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.auth.repositories.user_repository import UserRepository
from app.domains.auth.security import issue_tokens
from app.domains.auth.services.auth_service import AuthService
from app.domains.auth.services.token_registry import RefreshTokenRegistry


class _FakeRedis:
    """Minimal in-memory stand-in for the RedisCache primitives used."""

    def __init__(self):
        self.store: dict[str, str] = {}

    async def set(self, key, value, ttl=0):
        self.store[key] = value
        return True

    async def exists(self, key):
        return key in self.store


@pytest.mark.asyncio
async def test_registry_revoke_and_check_round_trip():
    registry = RefreshTokenRegistry(redis=_FakeRedis())

    assert await registry.is_revoked("abc") is False
    await registry.revoke("abc")
    assert await registry.is_revoked("abc") is True


@pytest.mark.asyncio
async def test_registry_ignores_empty_jti():
    registry = RefreshTokenRegistry(redis=_FakeRedis())

    await registry.revoke("")
    assert await registry.is_revoked("") is False


@pytest_asyncio.fixture
async def registered_user(db_session: AsyncSession):
    from app.domains.auth.models import User

    user = User(
        email="rotate@example.com", username="rotate_user", hashed_password="x"
    )
    db_session.add(user)
    await db_session.commit()
    return user


@pytest.mark.asyncio
async def test_refresh_rotation_rejects_replayed_token(db_session, registered_user):
    service = AuthService(
        UserRepository(db_session), revocation=RefreshTokenRegistry(redis=_FakeRedis())
    )
    tokens = issue_tokens(registered_user.id)

    _, rotated = await service.refresh(tokens.refresh_token)
    assert rotated.refresh_token != tokens.refresh_token

    from app.core.exceptions import UnauthorizedError

    with pytest.raises(UnauthorizedError):
        await service.refresh(tokens.refresh_token)


@pytest.mark.asyncio
async def test_logout_revokes_refresh_token(db_session, registered_user):
    registry = RefreshTokenRegistry(redis=_FakeRedis())
    service = AuthService(UserRepository(db_session), revocation=registry)
    tokens = issue_tokens(registered_user.id)

    await service.logout(tokens.refresh_token)

    assert await registry.is_revoked(tokens.session_id) is True


@pytest.mark.asyncio
async def test_logout_with_garbage_token_is_silent(db_session):
    service = AuthService(
        UserRepository(db_session), revocation=RefreshTokenRegistry(redis=_FakeRedis())
    )

    await service.logout("not-a-jwt")  # must not raise
