"""Focused tests for podcast bulk-delete behavior."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.podcast.models import Subscription
from app.domains.podcast.repositories.content_repository import (
    SubscriptionRepository,
)
from app.domains.podcast.services.episode_service import PodcastSubscriptionService


@pytest.fixture
def mock_db() -> AsyncMock:
    """Mock async DB session."""
    return AsyncMock(spec=AsyncSession)


@pytest.fixture
def mock_redis() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def service(mock_db: AsyncMock, mock_redis: AsyncMock) -> PodcastSubscriptionService:
    """Create service with mocked redis cache operations."""
    return PodcastSubscriptionService(mock_db, user_id=1, redis=mock_redis)


def _subscription(subscription_id: int = 1) -> Subscription:
    """Create lightweight subscription test object."""
    return SimpleNamespace(
        id=subscription_id,
        user_id=1,
        source_type="podcast-rss",
        title=f"sub-{subscription_id}",
    )


def _result_with_rows(rows: list) -> MagicMock:
    result = MagicMock()
    result.all.return_value = rows
    return result


@pytest.mark.asyncio
async def test_remove_subscriptions_bulk_all_success(
    service: PodcastSubscriptionService,
    mock_db: AsyncMock,
):
    # execute sequence: validate select, delete user-subscriptions,
    # remaining-subscribers select (empty -> all orphaned), delete orphans
    mock_db.execute.side_effect = [
        _result_with_rows(
            [SimpleNamespace(id=1), SimpleNamespace(id=2), SimpleNamespace(id=3)]
        ),
        MagicMock(),
        _result_with_rows([]),
        MagicMock(),
    ]

    result = await service.remove_subscriptions_bulk([1, 2, 3])

    assert result["success_count"] == 3
    assert result["failed_count"] == 0
    assert result["errors"] == []
    assert result["deleted_subscription_ids"] == [1, 2, 3]
    mock_db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_remove_subscriptions_bulk_partial_not_found(
    service: PodcastSubscriptionService,
    mock_db: AsyncMock,
):
    # id=2 does not belong to the user; id=3 still has another subscriber
    mock_db.execute.side_effect = [
        _result_with_rows([SimpleNamespace(id=1), SimpleNamespace(id=3)]),
        MagicMock(),
        _result_with_rows([SimpleNamespace(subscription_id=3)]),
        MagicMock(),
    ]

    result = await service.remove_subscriptions_bulk([1, 2, 3])

    assert result["success_count"] == 2
    assert result["failed_count"] == 1
    assert result["deleted_subscription_ids"] == [1, 3]
    assert result["errors"][0]["subscription_id"] == 2


@pytest.mark.asyncio
async def test_remove_subscriptions_bulk_db_error_propagates(
    service: PodcastSubscriptionService,
    mock_db: AsyncMock,
):
    # Batch delete is atomic: a database failure aborts the whole operation
    mock_db.execute.side_effect = RuntimeError("db down")

    with pytest.raises(RuntimeError, match="db down"):
        await service.remove_subscriptions_bulk([1, 2, 3])


@pytest.mark.asyncio
async def test_remove_subscription_returns_false_when_not_found(
    service: PodcastSubscriptionService,
):
    service._validate_and_get_subscription = AsyncMock(return_value=None)

    removed = await service.remove_subscription(1)

    assert removed is False


@pytest.mark.asyncio
async def test_remove_subscription_returns_false_when_delete_fails(
    service: PodcastSubscriptionService,
):
    service._validate_and_get_subscription = AsyncMock(return_value=_subscription(1))
    delete_mock = AsyncMock(return_value=False)

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(SubscriptionRepository, "delete_subscription", delete_mock)
        removed = await service.remove_subscription(1)

    assert removed is False


@pytest.mark.asyncio
async def test_remove_subscription_succeeds_and_invalidates_cache(
    service: PodcastSubscriptionService,
    mock_redis: AsyncMock,
):
    service._validate_and_get_subscription = AsyncMock(return_value=_subscription(1))
    delete_mock = AsyncMock(return_value=True)

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(SubscriptionRepository, "delete_subscription", delete_mock)
        removed = await service.remove_subscription(1)

    assert removed is True
    mock_redis.delete_pattern.assert_awaited_once_with("podcast:episodes:list:1:*")


@pytest.mark.asyncio
async def test_remove_subscription_succeeds_when_redis_unavailable(
    service: PodcastSubscriptionService,
    mock_redis: AsyncMock,
):
    service._validate_and_get_subscription = AsyncMock(return_value=_subscription(1))
    mock_redis.delete_pattern.side_effect = RuntimeError("redis unavailable")
    delete_mock = AsyncMock(return_value=True)

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(SubscriptionRepository, "delete_subscription", delete_mock)
        removed = await service.remove_subscription(1)

    assert removed is True


@pytest.mark.asyncio
async def test_bulk_delete_succeeds_when_redis_unavailable(
    service: PodcastSubscriptionService,
    mock_db: AsyncMock,
    mock_redis: AsyncMock,
):
    mock_db.execute.side_effect = [
        _result_with_rows(
            [SimpleNamespace(id=1), SimpleNamespace(id=2), SimpleNamespace(id=3)]
        ),
        MagicMock(),
        _result_with_rows([]),
        MagicMock(),
    ]
    mock_redis.delete_pattern.side_effect = RuntimeError("redis unavailable")

    result = await service.remove_subscriptions_bulk([1, 2, 3])

    assert result["success_count"] == 3
    assert result["failed_count"] == 0
    assert result["deleted_subscription_ids"] == [1, 2, 3]
