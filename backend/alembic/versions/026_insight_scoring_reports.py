"""insight tables + subscriptions.tier + drop legacy daily reports (Phase C)

Revision ID: 026
Revises: 025
Create Date: 2026-10-28

- 新增 ai_analyses / reports / ai_receipts（评分、三刊、成本台账）
- subscriptions.tier（T1 精选/T2 普通，默认 T2）——评分门槛分级依据
- drop 旧 per-user 日报表 podcast_daily_reports / podcast_daily_report_items
  （被全局三刊取代；相关代码同提交移除）
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "026"
down_revision: Union[str, Sequence[str], None] = "025"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)

    # -- subscriptions.tier --------------------------------------------------
    sub_columns = {c["name"] for c in inspector.get_columns("subscriptions")}
    if "tier" not in sub_columns:
        op.add_column(
            "subscriptions",
            sa.Column("tier", sa.String(4), nullable=False, server_default="T2"),
        )

    # -- ai_analyses -----------------------------------------------------------
    op.create_table(
        "ai_analyses",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "episode_id",
            sa.Integer(),
            sa.ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("selected", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("tags", sa.JSON(), nullable=True),
        sa.Column("category", sa.String(50), nullable=True),
        sa.Column("title_zh", sa.String(500), nullable=True),
        sa.Column("summary_zh", sa.Text(), nullable=True),
        sa.Column("reason_zh", sa.Text(), nullable=True),
        sa.Column("model", sa.String(120), nullable=True),
        sa.Column("prompt_version", sa.String(64), nullable=True),
        sa.Column("is_current", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("score >= 0 AND score <= 100", name="ck_ai_analyses_score"),
    )
    op.create_index(
        "ix_ai_analyses_episode_created", "ai_analyses", ["episode_id", "created_at"]
    )
    op.create_index(
        "uq_ai_analyses_current",
        "ai_analyses",
        ["episode_id"],
        unique=True,
        postgresql_where=sa.text("is_current"),
    )

    # -- reports ----------------------------------------------------------------
    op.create_table(
        "reports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("kind", sa.String(10), nullable=False),
        sa.Column("report_key", sa.String(10), nullable=False),
        sa.Column("window_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("window_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("content", sa.JSON(), nullable=False),
        sa.Column("model", sa.String(120), nullable=True),
        sa.Column("revision", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("kind", "report_key", name="uq_reports_kind_key"),
        sa.CheckConstraint("kind IN ('daily', 'weekly', 'monthly')", name="ck_reports_kind"),
    )
    op.create_index("ix_reports_kind_generated", "reports", ["kind", "generated_at"])

    # -- ai_receipts --------------------------------------------------------------
    op.create_table(
        "ai_receipts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("service", sa.String(20), nullable=False),
        sa.Column("operation", sa.String(40), nullable=False),
        sa.Column("model", sa.String(120), nullable=True),
        sa.Column("prompt_tokens", sa.Integer(), nullable=True),
        sa.Column("completion_tokens", sa.Integer(), nullable=True),
        sa.Column("audio_seconds", sa.Integer(), nullable=True),
        sa.Column("ok", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("duration_ms", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("service IN ('llm', 'transcription')", name="ck_ai_receipts_service"),
    )
    op.create_index("ix_ai_receipts_created", "ai_receipts", ["created_at"])
    op.create_index("ix_ai_receipts_service_created", "ai_receipts", ["service", "created_at"])

    # -- drop legacy per-user daily reports --------------------------------------
    if inspector.has_table("podcast_daily_report_items"):
        op.drop_table("podcast_daily_report_items")
    if inspector.has_table("podcast_daily_reports"):
        op.drop_table("podcast_daily_reports")


def downgrade() -> None:
    op.drop_table("ai_receipts")
    op.drop_table("reports")
    op.drop_index("uq_ai_analyses_current", table_name="ai_analyses")
    op.drop_table("ai_analyses")
    op.drop_column("subscriptions", "tier")

    # 旧日报表不恢复（其数据已不可逆删除）
