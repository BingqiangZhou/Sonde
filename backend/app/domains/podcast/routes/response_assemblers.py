"""Response assembly helpers for podcast API routes."""

from __future__ import annotations

from typing import Any

from app.domains.podcast.schemas import (
    DailyReportDateItem,
    PodcastDailyReportDatesResponse,
    PodcastEpisodeListResponse,
    PodcastEpisodeResponse,
    PodcastFeedResponse,
    PodcastPendingTranscriptionsResponse,
    PodcastPendingTranscriptionTaskResponse,
    SummaryModelInfo,
    SummaryModelsResponse,
)


def build_feed_response(
    episodes: list[dict[str, Any]],
    *,
    has_more: bool,
    next_page: int | None,
    next_cursor: str | None,
    total: int,
) -> PodcastFeedResponse:
    """Build the feed response envelope."""
    return PodcastFeedResponse(
        items=[PodcastEpisodeResponse(**episode) for episode in episodes],
        has_more=has_more,
        next_page=next_page,
        next_cursor=next_cursor,
        total=total,
    )


def build_episode_list_response(
    episodes: list[dict[str, Any]],
    *,
    total: int,
    page: int,
    size: int,
    subscription_id: int,
    next_cursor: str | None = None,
) -> PodcastEpisodeListResponse:
    """Build the paginated episode list response."""
    return PodcastEpisodeListResponse(
        items=[PodcastEpisodeResponse(**episode) for episode in episodes],
        total=total,
        page=page,
        size=size,
        pages=(total + size - 1) // size,
        subscription_id=subscription_id,
        next_cursor=next_cursor,
    )


def build_daily_report_dates_response(
    payload: dict[str, Any],
) -> PodcastDailyReportDatesResponse:
    """Build the report dates response."""
    items = [DailyReportDateItem(**item) for item in payload.get("dates", [])]
    return PodcastDailyReportDatesResponse(
        items=items,
        total=payload["total"],
        page=payload["page"],
        size=payload["size"],
        pages=payload["pages"],
    )


def build_pending_transcriptions_response(
    payload: dict[str, Any],
) -> PodcastPendingTranscriptionsResponse:
    """Build the pending transcription list response."""
    return PodcastPendingTranscriptionsResponse(
        items=[
            PodcastPendingTranscriptionTaskResponse(**task)
            for task in payload.get("tasks", [])
        ],
        total=payload["total"],
    )


def build_summary_models_response(
    models: list[dict[str, Any]],
) -> SummaryModelsResponse:
    """Build the summary models response."""
    model_infos = [
        SummaryModelInfo(
            id=model["id"],
            name=model["name"],
            display_name=model["display_name"],
            provider=model["provider"],
            model_id=model["model_id"],
            is_default=model["is_default"],
        )
        for model in models
    ]
    return SummaryModelsResponse(models=model_infos, total=len(model_infos))
