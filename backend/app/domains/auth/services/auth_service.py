"""Auth application service: register, login, refresh, profile rename."""

import logging
from datetime import UTC, datetime

import jwt as pyjwt

from app.core.exceptions import (
    ConflictError,
    InternalServerError,
    NotFoundError,
    UnauthorizedError,
    ValidationError,
)
from app.domains.auth.models import User
from app.domains.auth.repositories.user_repository import UserRepository
from app.domains.auth.security import (
    TokenBundle,
    decode_token,
    dummy_verify,
    generate_username,
    hash_password,
    issue_tokens,
    verify_password,
)
from app.domains.auth.services.token_registry import RefreshTokenRegistry


logger = logging.getLogger(__name__)

_USERNAME_GENERATION_ATTEMPTS = 3


class AuthService:
    def __init__(
        self,
        users: UserRepository,
        revocation: RefreshTokenRegistry | None = None,
    ):
        self._users = users
        self._revocation = revocation or RefreshTokenRegistry()

    async def register(self, email: str, password: str) -> tuple[User, TokenBundle]:
        normalized_email = email.strip().lower()
        if await self._users.get_by_email(normalized_email) is not None:
            raise ConflictError(
                "Email already registered",
                details={
                    "field": "email",
                    "message_en": "This email is already registered",
                    "message_zh": "该邮箱已被注册",
                },
            )
        username = await self._generate_unique_username()
        user = await self._users.create(
            email=normalized_email,
            username=username,
            hashed_password=hash_password(password),
        )
        logger.info("User registered: id=%s username=%s", user.id, user.username)
        return user, issue_tokens(user.id)

    async def _generate_unique_username(self) -> str:
        for _ in range(_USERNAME_GENERATION_ATTEMPTS):
            candidate = generate_username()
            if await self._users.get_by_username(candidate) is None:
                return candidate
        raise InternalServerError("Failed to generate a unique username")

    async def login(
        self, email_or_username: str, password: str
    ) -> tuple[User, TokenBundle]:
        identifier = email_or_username.strip()
        user = await self._users.get_by_email(identifier.lower())
        if user is None:
            user = await self._users.get_by_username(identifier)
        if user is None:
            dummy_verify(password)
            raise UnauthorizedError(
                "Invalid email or password",
                details={
                    "message_en": "Invalid email or password",
                    "message_zh": "邮箱或密码错误",
                },
            )
        if not verify_password(password, user.hashed_password):
            raise UnauthorizedError(
                "Invalid email or password",
                details={
                    "message_en": "Invalid email or password",
                    "message_zh": "邮箱或密码错误",
                },
            )
        if not user.is_active:
            raise UnauthorizedError(
                "Account is disabled",
                details={
                    "message_en": "This account has been disabled",
                    "message_zh": "该账号已被禁用",
                },
            )
        user.last_login_at = datetime.now(UTC)
        await self._users.save(user)
        return user, issue_tokens(user.id)

    async def refresh(self, refresh_token: str) -> tuple[User, TokenBundle]:
        try:
            payload = decode_token(refresh_token, "refresh")
            user_id = int(payload["sub"])
            jti = str(payload.get("jti", ""))
        except (pyjwt.InvalidTokenError, KeyError, ValueError) as exc:
            raise UnauthorizedError(
                "Invalid refresh token",
                details={
                    "message_en": "Please log in again",
                    "message_zh": "请重新登录",
                },
            ) from exc
        # Single-use refresh tokens: a replayed jti means the token was
        # rotated already (or explicitly logged out) — reject and revoke.
        if await self._revocation.is_revoked(jti):
            raise UnauthorizedError(
                "Refresh token no longer valid",
                details={
                    "message_en": "Please log in again",
                    "message_zh": "请重新登录",
                },
            )
        user = await self._users.get_by_id(user_id)
        if user is None or not user.is_active:
            raise UnauthorizedError(
                "Invalid refresh token",
                details={
                    "message_en": "Please log in again",
                    "message_zh": "请重新登录",
                },
            )
        await self._revocation.revoke(jti)
        return user, issue_tokens(user.id)

    async def logout(self, refresh_token: str | None) -> None:
        """Revoke the presented refresh token; access tokens expire on their own."""
        if not refresh_token:
            return
        try:
            payload = decode_token(refresh_token, "refresh")
        except pyjwt.InvalidTokenError:
            return
        await self._revocation.revoke(str(payload.get("jti", "")))

    async def get_user(self, user_id: int) -> User:
        user = await self._users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found")
        return user

    async def update_username(self, user_id: int, username: str) -> User:
        normalized = username.strip()
        if not 2 <= len(normalized) <= 30:
            raise ValidationError(
                "Username must be 2-30 characters",
                details={
                    "field": "username",
                    "message_en": "Username must be 2-30 characters",
                    "message_zh": "名称长度需在 2-30 个字符之间",
                },
            )
        user = await self.get_user(user_id)
        conflict = await self._users.get_by_username(normalized)
        if conflict is not None and conflict.id != user_id:
            raise ConflictError(
                "Username already taken",
                details={
                    "field": "username",
                    "message_en": "This name is already taken",
                    "message_zh": "该名称已被占用",
                },
            )
        user.username = normalized
        saved = await self._users.save(user)
        logger.info("User renamed: id=%s username=%s", saved.id, saved.username)
        return saved
