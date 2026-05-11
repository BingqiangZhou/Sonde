from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.domains.podcast.models import ProcessingStatus


class TranscriptCreate(BaseModel):
    episode_id: UUID
    content: str | None = None
    language: str | None = None
    duration: int | None = None
    word_count: int | None = None
    model_used: str | None = None
    error_message: str | None = None


class TranscriptResponse(BaseModel):
    id: UUID
    episode_id: UUID
    status: ProcessingStatus
    language: str | None = None
    duration: int | None = None
    word_count: int | None = None
    char_count: int | None = None
    processing_duration_sec: int | None = None
    rating: int | None = None
    model_used: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TranscriptSegment(BaseModel):
    start: float
    end: float
    text: str


class TranscriptDetail(TranscriptResponse):
    content: str | None = None
    segments: list[TranscriptSegment] | None = None

    model_config = ConfigDict(from_attributes=True)


class FeedbackRequest(BaseModel):
    rating: int = Field(ge=1, le=5)
    feedback: str | None = None


class BatchTranscribeRequest(BaseModel):
    episode_ids: list[UUID] | None = None
    filter_status: ProcessingStatus | None = None
    force: bool = False
