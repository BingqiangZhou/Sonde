"""System settings persistence (system_settings table).

Read + write live together here; domains and admin both consume this
module so repositories no longer depend on the admin app.
"""

from datetime import UTC, datetime
from typing import Any

from sqlalchemy import JSON, Column, DateTime, Integer, String, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import Base


class SystemSettings(Base):
    """System settings model for storing configuration values."""

    __tablename__ = "system_settings"

    id = Column(Integer, primary_key=True)
    key = Column(
        String(100), unique=True, nullable=False, index=True, comment="Setting key"
    )
    value = Column(JSON, nullable=True, comment="Setting value (JSON)")
    description = Column(String(500), nullable=True, comment="Setting description")
    category = Column(
        String(50),
        nullable=False,
        default="general",
        comment="Setting category: general, audio, ai, etc.",
    )

    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), comment="Created at"
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
        comment="Updated at",
    )

    def __repr__(self):
        return f"<SystemSettings(id={self.id}, key={self.key})>"


class DatabaseSettingsProvider:
    """Read system settings from the ``system_settings`` table."""

    async def get_setting(self, db: AsyncSession, key: str) -> dict[str, Any] | None:
        result = await db.execute(
            select(SystemSettings).where(SystemSettings.key == key),
        )
        setting = result.scalar_one_or_none()
        if setting and setting.value:
            return setting.value
        return None

    async def get_setting_value(
        self,
        db: AsyncSession,
        key: str,
        default: Any = None,
    ) -> Any:
        data = await self.get_setting(db, key)
        if data is None:
            return default
        return data.get("value", default) if isinstance(data, dict) else default


async def persist_setting(
    db: AsyncSession,
    key: str,
    value: dict[str, Any],
    *,
    description: str | None = None,
    category: str | None = None,
) -> SystemSettings:
    """Persist a system setting with get-or-create semantics."""
    result = await db.execute(select(SystemSettings).where(SystemSettings.key == key))
    setting = result.scalar_one_or_none()

    if setting:
        setting.value = value
    else:
        setting = SystemSettings(
            key=key,
            value=value,
            description=description,
            category=category,
        )
        db.add(setting)

    return setting
