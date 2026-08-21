"""Podcast episode, playback, summary, and search routes."""

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.auth import require_api_key
from app.core.exceptions import (
    EpisodeNotFoundError,
    ValidationError,
)
from app.domains.podcast.routes.dependencies import (
    get_podcast_episode_service,
    get_summary_workflow_service,
)
from app.domains.podcast.routes.episode_route_common import (
    decode_cursor,
    encode_keyset_cursor,
)
from app.domains.podcast.routes.response_assemblers import (
    build_episode_list_response,
    build_feed_response,
    build_summary_models_response,
)
from app.domains.podcast.schemas import (
    PodcastEpisodeDetailResponse,
    PodcastEpisodeFilter,
    PodcastEpisodeListResponse,
    PodcastEpisodeSyncResponse,
    PodcastFeedResponse,
    PodcastSummaryPendingResponse,
    PodcastSummaryRequest,
    PodcastSummaryStartResponse,
    SummaryModelsResponse,
)
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.summary_service import SummaryWorkflowService
from app.domains.podcast.tasks.tasks_summary import (
    generate_episode_summary as generate_episode_summary_task,
)


router = APIRouter(prefix="")
logger = logging.getLogger(__name__)


# ── Feed & episode listing ─────────────────────────────────────────────────


@router.get(
    "/episodes/feed",
    response_model=PodcastFeedResponse,
    summary="Get podcast feed",
)
async def get_podcast_feed(
    cursor: str | None = Query(None, description="Cursor token for pagination"),
    page_size: int = Query(10, ge=1, le=50, description="Page size"),
    size: int | None = Query(
        None,
        ge=1,
        le=50,
        description="Optional alias for page_size",
    ),
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
):
    """Return all subscribed episodes ordered by publish date desc."""
    resolved_size = size or page_size
    decoded = decode_cursor(cursor) if cursor else None

    (
        episodes,
        total,
        has_more,
        next_cursor_values,
    ) = await service.list_feed(
        size=resolved_size,
        cursor_published_at=decoded["ts"] if decoded else None,
        cursor_episode_id=decoded["id"] if decoded else None,
    )
    next_cursor = (
        encode_keyset_cursor(next_cursor_values[0], next_cursor_values[1])
        if next_cursor_values
        else None
    )

    return build_feed_response(
        episodes,
        has_more=has_more,
        next_page=None,
        next_cursor=next_cursor,
        total=total,
    )


@router.get(
    "/episodes",
    response_model=PodcastEpisodeListResponse,
    summary="List podcast episodes",
)
async def list_episodes(
    subscription_id: int | None = Query(None, description="Subscription ID filter"),
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    has_summary: bool | None = Query(None, description="Has AI summary"),
    is_played: bool | None = Query(None, description="Played status"),
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
):
    filters = PodcastEpisodeFilter(
        subscription_id=subscription_id,
        has_summary=has_summary,
        is_played=is_played,
    )
    episodes, total = await service.list_episodes(filters=filters, page=page, size=size)
    return build_episode_list_response(
        episodes,
        total=total,
        page=page,
        size=size,
        subscription_id=subscription_id or 0,
    )


@router.get(
    "/episodes/sync",
    response_model=PodcastEpisodeSyncResponse,
    summary="Incremental episode sync for client caches",
)
async def sync_episodes(
    cursor: str | None = Query(None, description="Cursor token from previous sync"),
    limit: int = Query(50, ge=1, le=200, description="Batch size"),
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
):
    """Return episodes ordered by updated_at ascending (oldest first).

    Client-cache hydration: call without a cursor for the initial pull, page
    until ``has_more`` is false, persist ``next_cursor`` as the sync
    watermark, and pass it back on later incremental syncs. Unlike the feed
    endpoint the AI summary text is kept for offline rendering.
    """
    decoded = decode_cursor(cursor) if cursor else None
    items, has_more, next_values = await service.list_sync(
        size=limit,
        cursor_updated_at=decoded["ts"] if decoded else None,
        cursor_episode_id=decoded["id"] if decoded else None,
    )
    next_cursor = (
        encode_keyset_cursor(next_values[0], next_values[1]) if next_values else None
    )
    return PodcastEpisodeSyncResponse(
        items=items,
        has_more=has_more,
        next_cursor=next_cursor,
    )


@router.get(
    "/episodes/{episode_id}",
    response_model=PodcastEpisodeDetailResponse,
    summary="Get episode detail",
)
async def get_episode(
    episode_id: int,
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
):
    episode = await service.get_episode_with_summary(episode_id)
    if not episode:
        raise HTTPException(
            status_code=404, detail="Episode not found or no permission"
        )

    return PodcastEpisodeDetailResponse(**episode)


# ── Summary & playback actions ─────────────────────────────────────────────


@router.post(
    "/episodes/{episode_id}/summary",
    response_model=PodcastSummaryStartResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Queue AI summary generation",
)
async def generate_summary(
    episode_id: int,
    request: PodcastSummaryRequest,
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    summary_workflow: SummaryWorkflowService = Depends(get_summary_workflow_service),
):
    try:
        episode = await service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Episode not found",
            )

        accepted = await summary_workflow.accept_episode_summary_generation(
            episode_id,
        )

        if not accepted["already_queued"]:
            generate_episode_summary_task.delay(
                episode_id,
                request.summary_model,
                request.custom_prompt,
            )

        return PodcastSummaryStartResponse(
            episode_id=episode_id,
            summary_status=accepted["summary_status"],
            accepted_at=accepted.get("accepted_at", datetime.now(UTC)),
            message=(
                "Summary generation already in progress"
                if accepted["already_queued"]
                else "Summary generation accepted"
            ),
        )
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transcript is required before generating summary",
        ) from exc
    except EpisodeNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Episode not found",
        ) from None
    except Exception as exc:
        logger.error("Failed to queue summary for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to queue summary generation",
        ) from exc


@router.get(
    "/summaries/pending",
    response_model=PodcastSummaryPendingResponse,
    summary="List pending summaries",
)
async def get_pending_summaries(
    user_id: int = Depends(require_api_key),
    summary_workflow: SummaryWorkflowService = Depends(get_summary_workflow_service),
):
    pending = await summary_workflow.list_pending_summaries_for_user(user_id)
    return PodcastSummaryPendingResponse(count=len(pending), episodes=pending)


@router.get(
    "/summaries/models",
    response_model=SummaryModelsResponse,
    summary="List available summary models",
)
async def get_summary_models(
    summary_workflow: SummaryWorkflowService = Depends(get_summary_workflow_service),
):
    try:
        models = await summary_workflow.get_summary_models()
        return build_summary_models_response(models)
    except Exception as exc:
        logger.error("Failed to get summary models: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── Search ──────────────────────────────────────────────────────────────────
