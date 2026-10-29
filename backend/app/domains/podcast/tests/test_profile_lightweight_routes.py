from unittest.mock import AsyncMock

from fastapi.testclient import TestClient


def test_get_profile_stats_returns_lightweight_fields(
    client: TestClient,
    mock_stats_service: AsyncMock,
):
    mock_stats_service.get_profile_stats.return_value = {
        "total_subscriptions": 3,
        "total_episodes": 42,
        "summaries_generated": 15,
        "pending_summaries": 27,
        "total_highlights": 6,
    }

    response = client.get("/api/v1/podcasts/stats/profile")

    assert response.status_code == 200
    data = response.json()
    assert data["total_subscriptions"] == 3
    assert data["total_episodes"] == 42
    assert data["summaries_generated"] == 15
    assert data["pending_summaries"] == 27
    assert data["total_highlights"] == 6
    mock_stats_service.get_profile_stats.assert_awaited_once_with()
