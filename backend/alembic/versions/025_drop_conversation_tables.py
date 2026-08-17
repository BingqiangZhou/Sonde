"""drop_conversation_tables

Revision ID: 025
Revises: f5b233bd4e12
Create Date: 2026-08-18 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = '025'
down_revision: Union[str, Sequence[str], None] = 'f5b233bd4e12'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Drop tables for the removed transcript-context chat feature."""
    op.drop_table("podcast_conversations")
    op.drop_table("conversation_sessions")


def downgrade() -> None:
    raise NotImplementedError("Cannot downgrade beyond conversation removal")
