"""Podcast-related FastAPI dependency providers.

This module provides all podcast domain services and repositories
using lazy imports to avoid circular dependencies.
"""

from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency, get_redis_client, require_user
from app.core.redis import RedisCache
from app.domains.podcast.conversation_service import ConversationService
from app.domains.podcast.repositories.content_repository import (
    SubscriptionRepository,
)
from app.domains.podcast.services.content_service import (
    HighlightService,
    SummaryWorkflowService,
)
from app.domains.podcast.services.episode_service import (
    PodcastEpisodeService,
    PodcastSubscriptionService,
)
from app.domains.podcast.services.schedule_service import PodcastScheduleService
from app.domains.podcast.services.search_service import PodcastSearchService
from app.domains.podcast.services.stats_service import PodcastStatsService
from app.domains.podcast.services.transcription_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)


# Cached repository classes (populated on first call)
_cached_repos: dict | None = None


def _get_repositories():
    """Lazy import repositories to avoid circular dependencies.

    Results are cached after the first call to avoid repeated imports.
    """
    global _cached_repos
    if _cached_repos is not None:
        return _cached_repos
    from app.domains.podcast.repositories import (
        PodcastEpisodeRepository,
        PodcastRepository,
        PodcastSearchRepository,
        PodcastStatsRepository,
        PodcastSubscriptionRepository,
    )

    _cached_repos = {
        "episode": PodcastEpisodeRepository,
        "search": PodcastSearchRepository,
        "stats": PodcastStatsRepository,
        "subscription": PodcastSubscriptionRepository,
        "summary": PodcastRepository,
    }
    return _cached_repos


def get_podcast_subscription_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast subscription/feed repository."""
    repos = _get_repositories()
    return repos["subscription"](db)


def get_podcast_episode_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast episode-query repository."""
    repos = _get_repositories()
    return repos["episode"](db)


def get_podcast_search_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast search repository."""
    repos = _get_repositories()
    return repos["search"](db)


def get_podcast_stats_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast stats repository."""
    repos = _get_repositories()
    return repos["stats"](db)


def get_podcast_summary_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast summary/transcription repository."""
    repos = _get_repositories()
    return repos["summary"](db)


def get_podcast_parser(
    user_id: int = Depends(require_user),
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
    user_id: int = Depends(require_user),
    repo=Depends(get_podcast_subscription_repository),
    subscription_repo=Depends(get_subscription_repository),
    redis: RedisCache = Depends(get_redis_client),
    parser=Depends(get_podcast_parser),
) -> PodcastSubscriptionService:
    """Provide request-scoped podcast subscription service."""
    return PodcastSubscriptionService(
        db,
        user_id,
        repo=repo,
        subscription_repo=subscription_repo,
        redis=redis,
        parser=parser,
    )


def get_podcast_episode_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_user),
    repo=Depends(get_podcast_episode_repository),
    redis: RedisCache = Depends(get_redis_client),
) -> PodcastEpisodeService:
    """Provide request-scoped podcast episode service."""
    return PodcastEpisodeService(db, user_id, repo=repo, redis=redis)


def get_podcast_schedule_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_user),
) -> PodcastScheduleService:
    """Provide request-scoped podcast schedule service."""
    return PodcastScheduleService(db, user_id)


def get_podcast_search_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_user),
    repo=Depends(get_podcast_search_repository),
    redis: RedisCache = Depends(get_redis_client),
) -> PodcastSearchService:
    """Provide request-scoped podcast search service."""
    return PodcastSearchService(db, user_id, repo=repo, redis=redis)


def get_podcast_stats_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_user),
    repo=Depends(get_podcast_stats_repository),
    redis: RedisCache = Depends(get_redis_client),
) -> PodcastStatsService:
    """Provide request-scoped podcast stats service."""
    return PodcastStatsService(
        db,
        user_id,
        repo=repo,
        redis=redis,
    )


def get_highlight_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(require_user),
    redis: RedisCache = Depends(get_redis_client),
) -> HighlightService:
    """Provide request-scoped podcast highlight service."""
    return HighlightService(db, user_id, redis=redis)


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


def get_conversation_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> ConversationService:
    """Provide request-scoped conversation service."""
    return ConversationService(db)


__all__ = [
    "get_conversation_service",
    "get_highlight_service",
    "get_podcast_episode_repository",
    "get_podcast_episode_service",
    "get_podcast_parser",
    "get_podcast_schedule_service",
    "get_podcast_search_repository",
    "get_podcast_search_service",
    "get_podcast_stats_repository",
    "get_podcast_stats_service",
    "get_podcast_subscription_repository",
    "get_podcast_subscription_service",
    "get_podcast_summary_repository",
    "get_podcast_task_orchestration_service",
    "get_summary_workflow_service",
    "require_user",
    "get_transcription_workflow_service",
]
