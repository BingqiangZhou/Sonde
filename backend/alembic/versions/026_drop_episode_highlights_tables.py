"""drop_episode_highlights_tables

Revision ID: 026
Revises: 025
Create Date: 2026-08-19 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = '026'
down_revision: Union[str, Sequence[str], None] = '025'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Drop tables for the removed highlights feature."""
    op.drop_table("episode_highlights")
    op.drop_table("highlight_extraction_tasks")


def downgrade() -> None:
    raise NotImplementedError("Cannot downgrade beyond highlights removal")
