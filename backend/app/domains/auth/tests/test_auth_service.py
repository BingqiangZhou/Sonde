"""Unit tests for auth service internals and username generation."""

from __future__ import annotations

import re
from unittest.mock import patch

import pytest

from app.domains.auth.repositories.user_repository import UserRepository
from app.domains.auth.security import generate_username
from app.domains.auth.services.auth_service import AuthService


PASSWORD = "Str0ngPass!"


def test_generate_username_format():
    name = generate_username()
    assert re.match(r"^user_\d{4}[a-z0-9]{4}$", name)


def test_generate_username_is_random():
    assert len({generate_username() for _ in range(20)}) > 1


class TestUsernameCollisionRetry:
    async def test_register_retries_on_username_collision(self, db_session):
        service = AuthService(UserRepository(db_session))
        await service.register("alice@example.com", PASSWORD)
        existing = await UserRepository(db_session).get_by_email("alice@example.com")

        candidates = iter([existing.username, "user_0101zzzz"])
        with patch(
            "app.domains.auth.services.auth_service.generate_username",
            side_effect=lambda: next(candidates),
        ):
            user, _ = await service.register("bob@example.com", PASSWORD)

        assert user.username == "user_0101zzzz"

    async def test_register_exhausts_retries(self, db_session):
        service = AuthService(UserRepository(db_session))
        await service.register("alice@example.com", PASSWORD)
        existing = await UserRepository(db_session).get_by_email("alice@example.com")

        with (
            patch(
                "app.domains.auth.services.auth_service.generate_username",
                return_value=existing.username,
            ),
            pytest.raises(Exception) as exc_info,
        ):
            await service.register("bob@example.com", PASSWORD)
        assert "unique username" in str(exc_info.value)
