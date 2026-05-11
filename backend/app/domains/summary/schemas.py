from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.domains.podcast.models import ProcessingStatus


class SummaryCreate(BaseModel):
    episode_id: UUID
    content: str | None = None
    key_topics: list[str] | None = None
    highlights: list[str] | None = None
    model_used: str | None = None
    provider: str | None = None


class SummaryResponse(BaseModel):
    id: UUID
    episode_id: UUID
    status: ProcessingStatus
    key_topics: list[str] | None = None
    highlights: list[str] | None = None
    model_used: str | None = None
    provider: str | None = None
    prompt_version_id: UUID | None = None
    quality_score: float | None = None
    rating: int | None = None
    feedback: str | None = None
    processing_duration_sec: int | None = None
    error_message: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SummaryDetail(SummaryResponse):
    content: str | None = None

    model_config = ConfigDict(from_attributes=True)


class FeedbackRequest(BaseModel):
    rating: int = Field(ge=1, le=5)
    feedback: str | None = None


class BatchSummarizeRequest(BaseModel):
    episode_ids: list[UUID] | None = None
    filter_status: ProcessingStatus | None = ProcessingStatus.PENDING
