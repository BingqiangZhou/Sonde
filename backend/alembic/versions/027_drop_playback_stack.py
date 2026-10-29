"""drop playback stack (tables + columns)

Revision ID: 027
Revises: 026
Create Date: 2026-10-29

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "027"
down_revision: Union[str, Sequence[str], None] = "026"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _drop_check_constraint(table: str, name: str) -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    names = {c["name"] for c in inspector.get_check_constraints(table)}
    if name in names:
        op.drop_constraint(name, table, type_="check")


def upgrade() -> None:
    """Drop playback/queue tables and playback columns."""
    conn = op.get_bind()
    inspector = sa.inspect(conn)

    if inspector.has_table("podcast_queue_items"):
        op.drop_table("podcast_queue_items")
    if inspector.has_table("podcast_queues"):
        op.drop_table("podcast_queues")
    if inspector.has_table("podcast_playback_states"):
        op.drop_table("podcast_playback_states")

    episode_columns = {
        col["name"] for col in inspector.get_columns("podcast_episodes")
    }
    if "play_count" in episode_columns:
        op.drop_column("podcast_episodes", "play_count")
    if "last_played_at" in episode_columns:
        op.drop_column("podcast_episodes", "last_played_at")

    _drop_check_constraint(
        "user_subscriptions", "ck_user_subscriptions_playback_rate_preference_range"
    )
    sub_columns = {
        col["name"] for col in inspector.get_columns("user_subscriptions")
    }
    if "playback_rate_preference" in sub_columns:
        op.drop_column("user_subscriptions", "playback_rate_preference")

    _drop_check_constraint("users", "ck_users_default_playback_rate_range")
    user_columns = {col["name"] for col in inspector.get_columns("users")}
    if "default_playback_rate" in user_columns:
        op.drop_column("users", "default_playback_rate")


def downgrade() -> None:
    """Recreate playback stack schema (data is not restored)."""
    op.create_table(
        "podcast_playback_states",
        sa.Column("id", sa.Integer(), nullable=False),
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
        sa.Column("current_position", sa.Integer(), server_default="0"),
        sa.Column("is_playing", sa.Boolean(), server_default=sa.false()),
        sa.Column("playback_rate", sa.Float(), nullable=False, server_default="1.0"),
        sa.Column(
            "last_updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
        ),
        sa.Column("play_count", sa.Integer(), server_default="0"),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint(
            "playback_rate >= 0.5 AND playback_rate <= 3.0",
            name="ck_podcast_playback_states_playback_rate_range",
        ),
    )
    op.create_index(
        "idx_user_episode_unique",
        "podcast_playback_states",
        ["user_id", "episode_id"],
        unique=True,
    )

    op.create_table(
        "podcast_queues",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "current_episode_id",
            sa.Integer(),
            sa.ForeignKey("podcast_episodes.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("revision", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", name="uq_podcast_queues_user_id"),
    )

    op.create_table(
        "podcast_queue_items",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column(
            "queue_id",
            sa.Integer(),
            sa.ForeignKey("podcast_queues.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "episode_id",
            sa.Integer(),
            sa.ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("queue_id", "episode_id", name="uq_podcast_queue_item_episode"),
        sa.UniqueConstraint("queue_id", "position", name="uq_podcast_queue_item_position"),
    )
    op.create_index(
        "idx_podcast_queue_items_queue_position",
        "podcast_queue_items",
        ["queue_id", "position"],
    )

    op.add_column(
        "podcast_episodes",
        sa.Column("play_count", sa.Integer(), server_default="0"),
    )
    op.add_column(
        "podcast_episodes",
        sa.Column("last_played_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "user_subscriptions",
        sa.Column("playback_rate_preference", sa.Float(), nullable=True),
    )
    op.create_check_constraint(
        "ck_user_subscriptions_playback_rate_preference_range",
        "user_subscriptions",
        "playback_rate_preference IS NULL OR "
        "(playback_rate_preference >= 0.5 AND playback_rate_preference <= 3.0)",
    )
    op.add_column(
        "users",
        sa.Column("default_playback_rate", sa.Float(), nullable=False, server_default="1.0"),
    )
    op.create_check_constraint(
        "ck_users_default_playback_rate_range",
        "users",
        "default_playback_rate >= 0.5 AND default_playback_rate <= 3.0",
    )
