"""stability contract fields

Revision ID: 8d2f7c4a1b9e
Revises: a5b33fe7c181
Create Date: 2026-05-12 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "8d2f7c4a1b9e"
down_revision: Union[str, None] = "a5b33fe7c181"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("episodes", sa.Column("source_url", sa.String(length=1000), nullable=True))
    op.add_column("episodes", sa.Column("external_id", sa.String(length=1000), nullable=True))
    op.add_column("transcripts", sa.Column("error_message", sa.Text(), nullable=True))
    op.add_column("summaries", sa.Column("error_message", sa.Text(), nullable=True))
    op.create_index("ix_episodes_podcast_external_id", "episodes", ["podcast_id", "external_id"])
    op.create_index("ix_episodes_podcast_source_url", "episodes", ["podcast_id", "source_url"])


def downgrade() -> None:
    op.drop_index("ix_episodes_podcast_source_url", table_name="episodes")
    op.drop_index("ix_episodes_podcast_external_id", table_name="episodes")
    op.drop_column("summaries", "error_message")
    op.drop_column("transcripts", "error_message")
    op.drop_column("episodes", "external_id")
    op.drop_column("episodes", "source_url")
