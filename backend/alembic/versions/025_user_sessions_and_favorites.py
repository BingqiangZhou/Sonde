"""user_sessions rebuild + user_favorites (Phase B multi-user restore)

Revision ID: 025
Revises: f5b233bd4e12
Create Date: 2026-10-28

- user_sessions：f5b233bd 曾随单用户化删除；多用户 JWT 恢复后重建（幂等）。
- user_favorites：per-user 单集收藏同步（替代 web localStorage 收藏）。
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "025"
down_revision: Union[str, Sequence[str], None] = "f5b233bd4e12"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)

    if not inspector.has_table("user_sessions"):
        op.create_table(
            "user_sessions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("session_token", sa.Text(), nullable=False),
            sa.Column("refresh_token", sa.Text(), nullable=True),
            sa.Column("device_info", sa.JSON(), nullable=True),
            sa.Column("ip_address", sa.String(45), nullable=True),
            sa.Column("user_agent", sa.Text(), nullable=True),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column(
                "last_activity_at", sa.DateTime(timezone=True), nullable=True
            ),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=True),
        )
        op.create_index("ix_user_sessions_session_token", "user_sessions", ["session_token"], unique=True)
        op.create_index("ix_user_sessions_refresh_token", "user_sessions", ["refresh_token"], unique=True)
        op.create_index("idx_user_active", "user_sessions", ["user_id", "is_active"])
        op.create_index("idx_user_sessions_token_expires", "user_sessions", ["session_token", "expires_at"])

    if not inspector.has_table("user_favorites"):
        op.create_table(
            "user_favorites",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "episode_id",
                sa.Integer(),
                sa.ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=True),
            sa.UniqueConstraint("user_id", "episode_id", name="uq_user_favorites"),
        )
        op.create_index(
            "ix_user_favorites_user_created", "user_favorites", ["user_id", "created_at"]
        )


def downgrade() -> None:
    op.drop_table("user_favorites")
    op.drop_table("user_sessions")
