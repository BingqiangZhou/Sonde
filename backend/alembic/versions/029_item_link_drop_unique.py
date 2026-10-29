"""podcast_episodes.item_link drop uniqueness (feeds may repeat detail links)

Revision ID: 029
Revises: 028
Create Date: 2026-10-29

Real-world feeds legitimately repeat the same <item><link> across distinct
episodes (e.g. Huberman Lab "Essentials" episodes all link to the same
/essentials page). A unique constraint on item_link made such feeds fail the
whole subscription with a 500. Keep a plain index for lookup performance; the
ingestion batch dedup matches episodes per link list, not a single row.
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "029"
down_revision: str | Sequence[str] | None = "028"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _constraint_exists(name: str) -> bool:
    conn = op.get_bind()
    result = conn.execute(
        sa.text(
            "SELECT 1 FROM pg_constraint WHERE conname = :name "
            "AND conrelid = 'podcast_episodes'::regclass"
        ),
        {"name": name},
    )
    return result.scalar() is not None


def _index_exists(name: str) -> bool:
    conn = op.get_bind()
    result = conn.execute(
        sa.text(
            "SELECT 1 FROM pg_indexes WHERE tablename = 'podcast_episodes' "
            "AND indexname = :name"
        ),
        {"name": name},
    )
    return result.scalar() is not None


def upgrade() -> None:
    if _constraint_exists("podcast_episodes_item_link_key"):
        op.drop_constraint(
            "podcast_episodes_item_link_key",
            "podcast_episodes",
            type_="unique",
        )
    if _index_exists("idx_podcast_episodes_item_link"):
        op.drop_index("idx_podcast_episodes_item_link", table_name="podcast_episodes")
    op.create_index(
        "idx_podcast_episodes_item_link",
        "podcast_episodes",
        ["item_link"],
        unique=False,
    )


def downgrade() -> None:
    # Deduplicate links (keep the lowest id per link) before restoring
    # uniqueness, otherwise the constraint creation fails on existing rows.
    op.execute(
        """
        DELETE FROM podcast_episodes a
        USING podcast_episodes b
        WHERE a.item_link IS NOT NULL
          AND a.item_link = b.item_link
          AND a.id > b.id
        """
    )
    op.drop_index("idx_podcast_episodes_item_link", table_name="podcast_episodes")
    op.create_index(
        "idx_podcast_episodes_item_link",
        "podcast_episodes",
        ["item_link"],
        unique=True,
    )
    op.create_unique_constraint(
        "podcast_episodes_item_link_key",
        "podcast_episodes",
        ["item_link"],
    )
