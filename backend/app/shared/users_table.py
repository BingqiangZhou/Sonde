"""Core (non-ORM) users table registration.

The auth domain was removed in the server-pipeline restructure, but the
``users`` table itself survives: it anchors ``user_id`` foreign keys
(``user_subscriptions``, daily reports) and holds the seeded operator row.
This module registers a minimal Core ``Table`` so ``Base.metadata`` can
resolve those foreign keys (test databases create schema from metadata;
Alembic migrations remain authoritative for production).
"""

from sqlalchemy import Column, DateTime, Integer, String, Table

from app.core.database import Base


users_table = Table(
    "users",
    Base.metadata,
    Column("id", Integer, primary_key=True),
    Column("email", String(255), nullable=False, unique=True, index=True),
    Column("username", String(100), nullable=True, unique=True, index=True),
    Column("hashed_password", String(255), nullable=False),
    Column("status", String(20), nullable=True, default="active"),
    Column("created_at", DateTime(timezone=True)),
    Column("updated_at", DateTime(timezone=True)),
)
