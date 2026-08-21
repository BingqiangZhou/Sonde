"""drop_unused_ai_model_config_columns

Revision ID: 027
Revises: 026
Create Date: 2026-08-21 00:00:00.000000

Drops ai_model_configs columns that were never read at runtime:
- max_retries (invocation uses settings.AI_CLIENT_MAX_RETRIES)
- rate_limit_per_minute (never enforced)
- cost_per_input_token / cost_per_output_token (write-only)
- is_system (always False; preset bootstrap is disabled)
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "027"
down_revision: Union[str, Sequence[str], None] = "026"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_column("ai_model_configs", "max_retries")
    op.drop_column("ai_model_configs", "rate_limit_per_minute")
    op.drop_column("ai_model_configs", "cost_per_input_token")
    op.drop_column("ai_model_configs", "cost_per_output_token")
    op.drop_column("ai_model_configs", "is_system")


def downgrade() -> None:
    op.add_column(
        "ai_model_configs",
        sa.Column("max_retries", sa.Integer(), nullable=True, server_default="3"),
    )
    op.add_column(
        "ai_model_configs",
        sa.Column(
            "rate_limit_per_minute", sa.Integer(), nullable=True, server_default="60"
        ),
    )
    op.add_column(
        "ai_model_configs", sa.Column("cost_per_input_token", sa.Float(), nullable=True)
    )
    op.add_column(
        "ai_model_configs",
        sa.Column("cost_per_output_token", sa.Float(), nullable=True),
    )
    op.add_column(
        "ai_model_configs",
        sa.Column("is_system", sa.Boolean(), nullable=True, server_default=sa.false()),
    )
