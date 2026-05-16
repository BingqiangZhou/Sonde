"""add active provider uniqueness

Revision ID: c7a45e2baf01
Revises: b8c44f2d9e17
Create Date: 2026-05-17 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "c7a45e2baf01"
down_revision: Union[str, None] = "b8c44f2d9e17"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        WITH ranked AS (
            SELECT id, row_number() OVER (ORDER BY created_at ASC, id ASC) AS rn
            FROM ai_provider_configs
            WHERE is_active = true
        )
        UPDATE ai_provider_configs
        SET is_active = false
        FROM ranked
        WHERE ai_provider_configs.id = ranked.id
          AND ranked.rn > 1
        """
    )
    op.create_index(
        "uq_ai_provider_configs_single_active",
        "ai_provider_configs",
        ["is_active"],
        unique=True,
        postgresql_where=sa.text("is_active = true"),
    )


def downgrade() -> None:
    op.drop_index("uq_ai_provider_configs_single_active", table_name="ai_provider_configs")
