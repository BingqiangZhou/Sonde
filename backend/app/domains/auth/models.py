"""User ORM model for the auth domain.

The ``users`` table predates this model (Alembic migration 001, extended by
003); column definitions mirror the live schema so metadata matches it.
Registration no longer accepts a client-provided name — ``username`` is
system-generated (see ``security.generate_username``) and stays editable via
``PATCH /auth/me``.
"""

from datetime import UTC, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    Float,
    Integer,
    String,
)

from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(UTC)


class User(Base):
    """Registered application user."""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    email = Column(String(255), nullable=False, unique=True, index=True)
    username = Column(String(100), nullable=True, unique=True, index=True)
    account_name = Column(String(255), nullable=True)
    hashed_password = Column(String(255), nullable=False)
    avatar_url = Column(String(500), nullable=True)
    status = Column(String(20), nullable=True, default="active")
    is_superuser = Column(Boolean, nullable=True, default=False)
    is_verified = Column(Boolean, nullable=True, default=False)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    settings = Column(JSON, nullable=True)
    preferences = Column(JSON, nullable=True)
    api_key = Column(String(255), nullable=True, unique=True)
    default_playback_rate = Column(
        Float, nullable=False, server_default="1.0", default=1.0
    )
    created_at = Column(DateTime(timezone=True), default=_utcnow)
    updated_at = Column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)

    __table_args__ = (
        CheckConstraint(
            "default_playback_rate >= 0.5 AND default_playback_rate <= 3.0",
            name="ck_users_default_playback_rate_range",
        ),
    )

    @property
    def is_active(self) -> bool:
        return (self.status or "active") == "active"
