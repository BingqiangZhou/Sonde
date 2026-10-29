"""podcast_episodes.item_link nullable (RSS feeds may omit <link>)

Revision ID: 028
Revises: 027
Create Date: 2026-10-29

Some real-world RSS feeds (e.g. Huberman Lab) omit the <item><link> element on
some episodes. The repository layer already treats item_link as optional and
dedups by link only when present; the NOT NULL column made such feeds fail the
whole subscription with a 500. Postgres unique indexes allow multiple NULLs, so
idx_podcast_episodes_item_link stays as-is.
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "028"
down_revision: str | Sequence[str] | None = "027"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "podcast_episodes",
        "item_link",
        existing_type=sa.String(length=500),
        nullable=True,
    )


def downgrade() -> None:
    # Backfill NULLs with the audio URL before restoring NOT NULL,
    # otherwise the constraint may fail on existing rows.
    op.execute(
        """
        UPDATE podcast_episodes
        SET item_link = audio_url
        WHERE item_link IS NULL
        """
    )
    op.alter_column(
        "podcast_episodes",
        "item_link",
        existing_type=sa.String(length=500),
        nullable=False,
    )
