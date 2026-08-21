"""Podcast-related FastAPI dependency providers.

This module provides all podcast domain services and repositories
using lazy imports to avoid circular dependencies.
"""

from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency, require_api_key
from app.domains.podcast.repositories.content_repository import SubscriptionRepository
from app.domains.podcast.repositories.podcast_repository import PodcastRepository
from app.domains.podcast.services.daily_report_service import DailyReportService
from app.domains.podcast.services.episode_service import (
    PodcastEpisodeService,
    PodcastSubscriptionService,
)
from app.domains.podcast.services.playback_service import (
    PodcastPlaybackService,
    PodcastQueueService,
)
from app.domains.podcast.services.schedule_service import PodcastScheduleService
from app.domains.podcast.services.search_service import PodcastSearchService
from app.domains.podcast.services.stats_service import PodcastStatsService
from app.domains.podcast.services.summary_service import SummaryWorkflowService
from app.domains.podcast.services.transcription_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)


# Podcast services legitimately cross aggregates (episode listing reads
# playback state, summary writes read episodes), so they share the composed
# PodcastRepository rather than narrow per-aggregate instances.
def get_podcast_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> PodcastRepository:
    """Provide the composed podcast repository."""
    return PodcastRepository(db)


def get_podcast_parser(
    user_id: int = Depends(require_api_key),
):
    """Provide the podcast RSS parser for the current user."""
    from app.domains.podcast.integration.secure_rss_parser import SecureRSSParser

    return SecureRSSParser(user_id)


def get_subscription_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> SubscriptionRepository:
    """Provide the generic subscription repository."""
    return SubscriptionRepository(db)


def get_podcast_subscription_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_api_key),
    repo=Depends(get_podcast_repository),
    subscription_repo=Depends(get_subscription_repository),
    parser=Depends(get_podcast_parser),
) -> PodcastSubscriptionService:
    """Provide request-scoped podcast subscription service."""
    return PodcastSubscriptionService(
        db,
        user_id,
        repo=repo,
        subscription_repo=subscription_repo,
        parser=parser,
    )


def get_podcast_episode_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_api_key),
    repo=Depends(get_podcast_repository),
) -> PodcastEpisodeService:
    """Provide request-scoped podcast episode service."""
    return PodcastEpisodeService(db, user_id, repo=repo)


def get_podcast_playback_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_api_key),
    repo=Depends(get_podcast_repository),
) -> PodcastPlaybackService:
    """Provide request-scoped playback service."""
    return PodcastPlaybackService(db, user_id, repo=repo)


def get_podcast_queue_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_api_key),
    repo=Depends(get_podcast_repository),
) -> PodcastQueueService:
    """Provide request-scoped podcast queue service."""
    return PodcastQueueService(db, user_id, repo=repo)


def get_podcast_schedule_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_api_key),
) -> PodcastScheduleService:
    """Provide request-scoped podcast schedule service."""
    return PodcastScheduleService(db, user_id)


def get_podcast_search_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_api_key),
    repo=Depends(get_podcast_repository),
) -> PodcastSearchService:
    """Provide request-scoped podcast search service."""
    return PodcastSearchService(db, user_id, repo=repo)


def get_podcast_stats_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_api_key),
    repo=Depends(get_podcast_repository),
    playback_service: PodcastPlaybackService = Depends(get_podcast_playback_service),
) -> PodcastStatsService:
    """Provide request-scoped stats service."""
    return PodcastStatsService(
        db,
        user_id,
        repo=repo,
        playback_service=playback_service,
    )


def get_daily_report_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_api_key),
) -> DailyReportService:
    """Provide request-scoped podcast daily report service."""
    return DailyReportService(db, user_id)


def get_summary_workflow_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> SummaryWorkflowService:
    """Provide request-scoped summary orchestration service."""
    return SummaryWorkflowService(db)


def get_transcription_workflow_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> TranscriptionWorkflowService:
    """Provide request-scoped transcription orchestration service."""
    return TranscriptionWorkflowService(db)


def get_podcast_task_orchestration_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> PodcastTaskOrchestrationService:
    """Provide request-scoped background-task orchestration service."""
    return PodcastTaskOrchestrationService(db)


__all__ = [
    "get_daily_report_service",
    "get_podcast_episode_service",
    "get_podcast_parser",
    "get_podcast_playback_service",
    "get_podcast_queue_service",
    "get_podcast_repository",
    "get_podcast_schedule_service",
    "get_podcast_search_service",
    "get_podcast_stats_service",
    "get_podcast_subscription_service",
    "get_podcast_task_orchestration_service",
    "get_subscription_repository",
    "get_summary_workflow_service",
    "require_api_key",
    "get_transcription_workflow_service",
]
