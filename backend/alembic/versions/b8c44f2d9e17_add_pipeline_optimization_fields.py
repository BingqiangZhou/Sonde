"""add pipeline optimization fields

Revision ID: b8c44f2d9e17
Revises: a5b33fe7c181
Create Date: 2026-04-26 12:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = 'b8c44f2d9e17'
down_revision: Union[str, None] = 'a5b33fe7c181'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # New table: prompt_templates
    op.create_table(
        'prompt_templates',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('version', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    # Podcasts: add priority
    op.add_column('podcasts', sa.Column('priority', sa.Integer(), nullable=False, server_default='0'))

    # Transcripts: add new columns
    op.add_column('transcripts', sa.Column('char_count', sa.Integer(), nullable=True))
    op.add_column('transcripts', sa.Column('processing_duration_sec', sa.Integer(), nullable=True))
    op.add_column('transcripts', sa.Column('rating', sa.Integer(), nullable=True))
    op.add_column('transcripts', sa.Column('feedback', sa.Text(), nullable=True))

    # Summaries: add new columns
    op.add_column(
        'summaries',
        sa.Column(
            'prompt_version_id',
            sa.Uuid(),
            sa.ForeignKey('prompt_templates.id', ondelete='SET NULL'),
            nullable=True,
        ),
    )
    op.add_column('summaries', sa.Column('quality_score', sa.Float(), nullable=True))
    op.add_column('summaries', sa.Column('rating', sa.Integer(), nullable=True))
    op.add_column('summaries', sa.Column('feedback', sa.Text(), nullable=True))
    op.add_column('summaries', sa.Column('processing_duration_sec', sa.Integer(), nullable=True))


def downgrade() -> None:
    # Summaries: drop new columns
    op.drop_column('summaries', 'processing_duration_sec')
    op.drop_column('summaries', 'feedback')
    op.drop_column('summaries', 'rating')
    op.drop_column('summaries', 'quality_score')
    op.drop_column('summaries', 'prompt_version_id')

    # Transcripts: drop new columns
    op.drop_column('transcripts', 'feedback')
    op.drop_column('transcripts', 'rating')
    op.drop_column('transcripts', 'processing_duration_sec')
    op.drop_column('transcripts', 'char_count')

    # Podcasts: drop priority
    op.drop_column('podcasts', 'priority')

    # Drop prompt_templates table
    op.drop_table('prompt_templates')
