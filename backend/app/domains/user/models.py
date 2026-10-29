"""User domain models（Phase B 自 v0 历史恢复）。

- User：表自 001/003 迁移起一直存在（024 删过 2FA 列），此处补回 ORM 模型。
- UserSession：会话/设备管理（f5b233bd 曾删表，025 迁移重建）。
- PasswordReset 未恢复：forgot/reset-password 首版走管理员重置（501）。
"""

from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class UserStatus(StrEnum):
    """User status."""

    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"


class User(Base):
    """User model（列集与现库对齐：001 + 024 去除 2FA + 027 去除播放倍速）。"""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(100), unique=True, index=True, nullable=True)
    account_name = Column(String(255), nullable=True)
    hashed_password = Column(String(255), nullable=False)
    avatar_url = Column(String(500), nullable=True)
    status = Column(String(20), default=UserStatus.ACTIVE)
    is_superuser = Column(Boolean, default=False)
    is_verified = Column(Boolean, default=False)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    settings = Column(JSON, nullable=True, default=dict)
    preferences = Column(JSON, nullable=True, default=dict)
    api_key = Column(String(255), unique=True, nullable=True)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    sessions = relationship(
        "UserSession", cascade="all, delete-orphan", lazy="selectin"
    )

    __table_args__ = (
        Index("idx_email_status", "email", "status"),
        Index("idx_username_status", "username", "status"),
    )

    @property
    def is_active(self) -> bool:
        """Check if user is active based on status."""
        return self.status == UserStatus.ACTIVE


class UserSession(Base):
    """User session model for tracking active sessions (025 重建)."""

    __tablename__ = "user_sessions"

    id = Column(Integer, primary_key=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    session_token = Column(Text, unique=True, index=True, nullable=False)
    refresh_token = Column(Text, unique=True, index=True, nullable=True)
    device_info = Column(JSON, nullable=True)
    ip_address = Column(String(45), nullable=True)  # IPv6 compatible
    user_agent = Column(Text, nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    last_activity_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))

    __table_args__ = (
        Index("idx_user_active", "user_id", "is_active"),
        Index("idx_user_sessions_token_expires", "session_token", "expires_at"),
    )
