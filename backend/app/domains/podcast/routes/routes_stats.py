"""Podcast stats routes."""

from fastapi import APIRouter, Depends

from app.domains.podcast.routes.dependencies import get_podcast_stats_service
from app.domains.podcast.schemas import PodcastProfileStatsResponse
from app.domains.podcast.services.stats_service import PodcastStatsService


router = APIRouter(prefix="")


@router.get(
    "/stats/profile",
    response_model=PodcastProfileStatsResponse,
    summary="Get lightweight profile stats",
)
async def get_profile_stats(
    service: PodcastStatsService = Depends(get_podcast_stats_service),
):
    """Get lightweight profile statistics for profile cards."""
    stats = await service.get_profile_stats()
    return PodcastProfileStatsResponse(**stats)
