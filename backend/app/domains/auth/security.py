"""Password hashing, JWT session tokens, and generated usernames."""

import secrets
import string
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import bcrypt
import jwt

from app.core.config import get_settings


ACCESS_TOKEN_TTL = timedelta(minutes=30)
REFRESH_TOKEN_TTL = timedelta(days=14)

_GENERATED_SUFFIX_ALPHABET = string.ascii_lowercase + string.digits


def generate_username() -> str:
    """Generate ``user_<MMDD><4 random [a-z0-9]>``, e.g. ``user_0817x9k2``.

    The date prefix keeps names traceable to the registration day; the random
    suffix keeps collisions negligible (36^4 per day).
    """
    suffix = "".join(secrets.choice(_GENERATED_SUFFIX_ALPHABET) for _ in range(4))
    return f"user_{datetime.now(UTC):%m%d}{suffix}"


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("ascii")


def verify_password(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("ascii"))
    except ValueError:
        return False


# Hashed form of an unknowable secret; used to equalize timing when the
# login identifier does not match any account.
_DUMMY_HASH = hash_password("not-a-real-password")


def dummy_verify(password: str) -> None:
    """Burn the same CPU time as a real password check, then discard."""
    verify_password(password, _DUMMY_HASH)


@dataclass(frozen=True, slots=True)
class TokenBundle:
    access_token: str
    refresh_token: str
    token_type: str
    expires_in: int
    expires_at: datetime
    session_id: str


def _create_token(
    user_id: int, token_type: str, ttl: timedelta
) -> tuple[str, datetime, str]:
    now = datetime.now(UTC)
    expires_at = now + ttl
    jti = secrets.token_hex(8)
    payload = {
        "sub": str(user_id),
        "type": token_type,
        "iat": now,
        "exp": expires_at,
        "jti": jti,
    }
    token = jwt.encode(payload, get_settings().get_secret_key(), algorithm="HS256")
    return token, expires_at, jti


def issue_tokens(user_id: int) -> TokenBundle:
    """Mint a fresh access/refresh pair (refresh ``jti`` is the session id)."""
    access_token, access_expires_at, _ = _create_token(
        user_id, "access", ACCESS_TOKEN_TTL
    )
    refresh_token, _, session_id = _create_token(user_id, "refresh", REFRESH_TOKEN_TTL)
    return TokenBundle(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=int(ACCESS_TOKEN_TTL.total_seconds()),
        expires_at=access_expires_at,
        session_id=session_id,
    )


def decode_token(token: str, expected_type: str) -> dict:
    """Decode a JWT and enforce its type; raises ``jwt.InvalidTokenError``.

    ``jwt.decode`` validates the signature and expiry before we check the
    type, so expired/wrong-type tokens never leak a payload.
    """
    payload = jwt.decode(token, get_settings().get_secret_key(), algorithms=["HS256"])
    if payload.get("type") != expected_type:
        raise jwt.InvalidTokenError(f"expected {expected_type} token")
    return payload
