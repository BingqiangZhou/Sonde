from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.services.stats_service import PodcastStatsService


@pytest.mark.asyncio
async def test_get_profile_stats_returns_repo_payload():
    service = PodcastStatsService(db=AsyncMock(), user_id=1)
    service.repo = AsyncMock()
    service.repo.get_profile_stats_aggregated.return_value = {
        "total_subscriptions": 2,
        "total_episodes": 10,
        "summaries_generated": 4,
        "pending_summaries": 6,
        "played_episodes": 3,
        "latest_daily_report_date": None,
    }

    result = await service.get_profile_stats()

    assert result["played_episodes"] == 3
    service.repo.get_profile_stats_aggregated.assert_awaited_once_with(1)
