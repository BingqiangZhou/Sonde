"""Password hashing (bcrypt) and secret generation.

自 v0 历史实现恢复；密码重置令牌相关函数未恢复（forgot/reset-password 首版走管理员重置）。
"""

from __future__ import annotations

import logging
import secrets

import bcrypt


logger = logging.getLogger(__name__)


def get_password_hash(password: str) -> str:
    """Hash password using bcrypt."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify plain password against hashed password（恒时比较由 bcrypt 保证）。"""
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8"),
        )
    except (ValueError, TypeError):
        logger.warning("Password verification failed on malformed hash")
        return False


def generate_api_key() -> str:
    """Generate a secure API key."""
    return secrets.token_urlsafe(32)


def generate_random_string(length: int = 32) -> str:
    """Generate a random string."""
    return secrets.token_urlsafe(length)
