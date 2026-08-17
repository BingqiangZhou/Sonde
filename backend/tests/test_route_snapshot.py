"""Route snapshot checks for critical API path migrations."""

from app.main import app


def _route_paths() -> set[str]:
    return {route.path for route in app.routes}


def test_all_routes_use_api_v1_prefix() -> None:
    """Every HTTP route must live under /api/v1/ — no bare-root paths."""
    paths = _route_paths()

    assert "/api/v1/" in paths
    assert "/api/v1/health" in paths
    assert "/api/v1/health/ready" in paths
    assert "/api/v1/docs" in paths
    assert "/api/v1/redoc" in paths
    assert "/api/v1/openapi.json" in paths

    for path in paths:
        assert path.startswith("/api/v1/"), f"route outside /api/v1/: {path}"


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


def test_auth_routes_exist() -> None:
    paths = _route_paths()

    assert "/api/v1/auth/register" in paths
    assert "/api/v1/auth/login" in paths
    assert "/api/v1/auth/refresh" in paths
    assert "/api/v1/auth/logout" in paths
    assert "/api/v1/auth/me" in paths


def test_queue_routes_exist() -> None:
    paths = _route_paths()

    assert "/api/v1/podcasts/queue" in paths
    assert "/api/v1/podcasts/queue/items" in paths
    assert "/api/v1/podcasts/queue/items/{episode_id}" in paths
    assert "/api/v1/podcasts/queue/items/reorder" in paths
    assert "/api/v1/podcasts/queue/current" in paths
    assert "/api/v1/podcasts/queue/current/complete" in paths
    assert "/api/v1/podcasts/queue/activate" in paths
