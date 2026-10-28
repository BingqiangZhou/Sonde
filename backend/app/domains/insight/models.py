"""Insight 域模型（Phase C：AI 评分、三刊、成本台账）。

设计对齐 ts-era：analyses 追加式留史（is_current 翻转）、reports 全局唯一
（UNIQUE(kind, report_key)，重生成 revision+1）、receipts 只增不改。
"""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class AiAnalysis(Base):
    """单集 AI 判定：评分 → 门槛 → 过线写作。保留历史，is_current 标记最新。"""

    __tablename__ = "ai_analyses"

    id = Column(Integer, primary_key=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    score = Column(Integer, nullable=False)
    selected = Column(Boolean, nullable=False, default=False)
    reason = Column(Text, nullable=True)
    tags = Column(JSON, nullable=True, default=list)
    category = Column(String(50), nullable=True)
    title_zh = Column(String(500), nullable=True)
    summary_zh = Column(Text, nullable=True)
    reason_zh = Column(Text, nullable=True)
    model = Column(String(120), nullable=True)
    prompt_version = Column(String(64), nullable=True)
    is_current = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))

    episode = relationship("PodcastEpisode")

    __table_args__ = (
        CheckConstraint("score >= 0 AND score <= 100", name="ck_ai_analyses_score"),
        # 每集至多一条 current（部分唯一索引，PG/SQLite 均支持）
        Index(
            "uq_ai_analyses_current",
            "episode_id",
            unique=True,
            sqlite_where=text("is_current"),
            postgresql_where=text("is_current"),
        ),
        Index("ix_ai_analyses_episode_created", "episode_id", "created_at"),
    )


class Report(Base):
    """全局三刊：daily / weekly / monthly。report_key：daily/weekly=YYYY-MM-DD（周一），monthly=YYYY-MM。"""

    __tablename__ = "reports"

    id = Column(Integer, primary_key=True)
    kind = Column(String(10), nullable=False)
    report_key = Column(String(10), nullable=False)
    window_start = Column(DateTime(timezone=True), nullable=False)
    window_end = Column(DateTime(timezone=True), nullable=False)
    content = Column(JSON, nullable=False)
    model = Column(String(120), nullable=True)
    revision = Column(Integer, nullable=False, default=1)
    generated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))

    __table_args__ = (
        UniqueConstraint("kind", "report_key", name="uq_reports_kind_key"),
        CheckConstraint(
            "kind IN ('daily', 'weekly', 'monthly')", name="ck_reports_kind"
        ),
        Index("ix_reports_kind_generated", "kind", "generated_at"),
    )


class AiReceipt(Base):
    """付费调用成本台账：LLM 与转写；失败也记（ok=false）。"""

    __tablename__ = "ai_receipts"

    id = Column(Integer, primary_key=True)
    service = Column(String(20), nullable=False)  # llm | transcription
    operation = Column(String(40), nullable=False)  # score | write | report | transcribe | summary
    model = Column(String(120), nullable=True)
    prompt_tokens = Column(Integer, nullable=True)
    completion_tokens = Column(Integer, nullable=True)
    audio_seconds = Column(Integer, nullable=True)
    ok = Column(Boolean, nullable=False, default=True)
    error = Column(Text, nullable=True)
    duration_ms = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))

    __table_args__ = (
        CheckConstraint(
            "service IN ('llm', 'transcription')", name="ck_ai_receipts_service"
        ),
        Index("ix_ai_receipts_created", "created_at"),
        Index("ix_ai_receipts_service_created", "service", "created_at"),
    )
