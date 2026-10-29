"""Route snapshot checks for critical API path migrations."""

from app.main import app


def _route_paths() -> set[str]:
    return {route.path for route in app.routes}


def test_podcast_subscription_routes_use_podcast_domain_prefix() -> None:
    paths = _route_paths()

    assert "/api/v1/podcasts/subscriptions" in paths
    assert "/api/v1/podcasts/subscriptions/bulk-delete" in paths
    assert "/api/v1/podcasts/subscriptions/{subscription_id}" in paths
    assert "/api/v1/podcasts/subscriptions/{subscription_id}/refresh" in paths
    assert "/api/v1/podcasts/subscriptions/{subscription_id}/reparse" in paths
    assert "/api/v1/podcasts/subscriptions/{subscription_id}/schedule" in paths
    assert "/api/v1/podcasts/subscriptions/schedule/all" in paths
    assert "/api/v1/podcasts/subscriptions/schedule/batch-update" in paths


def test_legacy_subscription_podcasts_routes_removed() -> None:
    paths = _route_paths()

    assert "/api/v1/subscriptions/podcasts" not in paths
    assert "/api/v1/subscriptions/podcasts/bulk-delete" not in paths
    assert "/api/v1/subscriptions/podcasts/{subscription_id}" not in paths
    assert "/api/v1/subscriptions/podcasts/{subscription_id}/refresh" not in paths
    assert "/api/v1/subscriptions/podcasts/{subscription_id}/reparse" not in paths
    assert "/api/v1/subscriptions/podcasts/{subscription_id}/schedule" not in paths
    assert "/api/v1/subscriptions/podcasts/schedule/all" not in paths
    assert "/api/v1/subscriptions/podcasts/schedule/batch-update" not in paths


# Monitoring routes have been removed


def test_playback_and_queue_routes_removed() -> None:
    paths = _route_paths()

    for removed in (
        "/api/v1/podcasts/queue",
        "/api/v1/podcasts/queue/items",
        "/api/v1/podcasts/queue/items/{episode_id}",
        "/api/v1/podcasts/queue/items/reorder",
        "/api/v1/podcasts/queue/current",
        "/api/v1/podcasts/queue/current/complete",
        "/api/v1/podcasts/queue/activate",
        "/api/v1/podcasts/episodes/history",
        "/api/v1/podcasts/episodes/history-lite",
        "/api/v1/podcasts/episodes/{episode_id}/playback",
        "/api/v1/podcasts/playback/rate/effective",
        "/api/v1/podcasts/playback/rate/apply",
        "/api/v1/podcasts/stats",
    ):
        assert removed not in paths, f"removed playback route still present: {removed}"
