"""drop_client_side_tables

Revision ID: 029
Revises: 028
Create Date: 2026-08-21 00:00:00.000000

Drops the playback/queue tables whose truth moved to the Flutter app's
on-device database (server-pipeline restructure, phase 3). The users table
stays: it anchors user_id foreign keys (user_subscriptions, daily reports)
and is seeded with the fixed operator row at startup.
"""

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "029"
down_revision: Union[str, Sequence[str], None] = "028"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLES = ("podcast_playback_states", "podcast_queues", "podcast_queue_items")


def upgrade() -> None:
    for table in _TABLES:
        op.execute(f"DROP TABLE IF EXISTS {table} CASCADE")


def downgrade() -> None:
    # Client-side truth cannot be restored from the server; recreating the
    # empty shapes is the best-effort inverse.
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS podcast_playback_states (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL,
            episode_id INTEGER NOT NULL,
            current_position INTEGER NOT NULL DEFAULT 0,
            is_playing BOOLEAN NOT NULL DEFAULT FALSE,
            playback_rate DOUBLE PRECISION NOT NULL DEFAULT 1.0,
            play_count INTEGER NOT NULL DEFAULT 0,
            last_updated_at TIMESTAMPTZ
        )
        """
    )
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS podcast_queues (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL,
            current_episode_id INTEGER,
            revision INTEGER NOT NULL DEFAULT 0,
            updated_at TIMESTAMPTZ
        )
        """
    )
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS podcast_queue_items (
            id SERIAL PRIMARY KEY,
            queue_id INTEGER NOT NULL,
            episode_id INTEGER NOT NULL,
            position INTEGER NOT NULL DEFAULT 0,
            added_at TIMESTAMPTZ
        )
        """
    )
