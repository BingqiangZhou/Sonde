import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.domains.podcast.models import ProcessingStatus

if TYPE_CHECKING:
    from app.domains.podcast.models import Episode
    from app.domains.settings.models import PromptTemplate


class Summary(Base):
    __tablename__ = "summaries"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    episode_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("episodes.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    content: Mapped[str | None] = mapped_column(Text, nullable=True)
    key_topics: Mapped[list[str] | None] = mapped_column(JSONB, nullable=True)
    highlights: Mapped[list[str] | None] = mapped_column(JSONB, nullable=True)
    model_used: Mapped[str | None] = mapped_column(String(100), nullable=True)
    provider: Mapped[str | None] = mapped_column(String(100), nullable=True)
    prompt_version_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("prompt_templates.id", ondelete="SET NULL"), nullable=True
    )
    quality_score: Mapped[float | None] = mapped_column(nullable=True)
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    feedback: Mapped[str | None] = mapped_column(Text, nullable=True)
    processing_duration_sec: Mapped[int | None] = mapped_column(Integer, nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[ProcessingStatus] = mapped_column(
        Enum(ProcessingStatus), nullable=False, default=ProcessingStatus.PENDING
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    episode: Mapped["Episode"] = relationship(back_populates="summary")
    prompt_template: Mapped["PromptTemplate | None"] = relationship()
