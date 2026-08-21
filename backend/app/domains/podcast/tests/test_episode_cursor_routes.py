from datetime import UTC, datetime
from unittest.mock import AsyncMock

from fastapi.testclient import TestClient

from app.domains.podcast.routes.dependencies import (
    get_podcast_episode_service,
    get_podcast_search_service,
)
from app.domains.podcast.routes.episode_route_common import encode_keyset_cursor
from app.main import app


def _sample_episode(now: datetime) -> dict:
    return {
        "id": 1,
        "subscription_id": 1,
        "title": "Episode 1",
        "description": "desc",
        "audio_url": "https://example.com/audio.mp3",
        "audio_duration": 1200,
        "published_at": now,
        "play_count": 0,
        "is_playing": False,
        "playback_rate": 1.0,
        "is_played": False,
        "status": "published",
        "created_at": now,
        "updated_at": now,
    }


def test_feed_rejects_malformed_cursor():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_episode_service] = lambda: service
    client = TestClient(app)

    import base64

    bogus_cursor = base64.urlsafe_b64encode(b"not-json").decode("utf-8").rstrip("=")

    response = client.get(
        f"/api/v1/podcasts/episodes/feed?cursor={bogus_cursor}&page_size=10",
    )

    assert response.status_code == 400
    service.list_feed.assert_not_called()

    app.dependency_overrides.pop(get_podcast_episode_service, None)


def test_feed_first_page_uses_keyset_path():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_episode_service] = lambda: service
    client = TestClient(app)

    now = datetime.now(UTC)
    service.list_feed.return_value = (
        [_sample_episode(now)],
        25,
        True,
        (now, 1),
    )

    response = client.get("/api/v1/podcasts/episodes/feed?page=1&page_size=10")

    assert response.status_code == 200
    payload = response.json()
    assert payload["next_page"] is None
    assert payload["next_cursor"]
    service.list_feed.assert_awaited_once_with(
        size=10,
        cursor_published_at=None,
        cursor_episode_id=None,
    )

    app.dependency_overrides.pop(get_podcast_episode_service, None)


def test_feed_accepts_size_alias():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_episode_service] = lambda: service
    client = TestClient(app)

    now = datetime.now(UTC)
    service.list_feed.return_value = (
        [_sample_episode(now)],
        25,
        False,
        None,
    )

    response = client.get("/api/v1/podcasts/episodes/feed?size=11")

    assert response.status_code == 200
    service.list_feed.assert_awaited_once_with(
        size=11,
        cursor_published_at=None,
        cursor_episode_id=None,
    )

    app.dependency_overrides.pop(get_podcast_episode_service, None)


def test_feed_keyset_cursor_path():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_episode_service] = lambda: service
    client = TestClient(app)

    now = datetime.now(UTC)
    service.list_feed.return_value = (
        [_sample_episode(now)],
        100,
        True,
        (now, 1),
    )
    keyset_cursor = encode_keyset_cursor(now, 999)

    response = client.get(
        f"/api/v1/podcasts/episodes/feed?cursor={keyset_cursor}&page_size=10",
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["has_more"] is True
    assert payload["next_cursor"]
    service.list_feed.assert_awaited_once()
    call_kwargs = service.list_feed.await_args.kwargs
    assert call_kwargs["cursor_episode_id"] == 999
    assert call_kwargs["cursor_published_at"] == now.astimezone(UTC).replace(
        tzinfo=None,
    )

    app.dependency_overrides.pop(get_podcast_episode_service, None)


def test_history_uses_page_pagination():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_episode_service] = lambda: service
    client = TestClient(app)

    now = datetime.now(UTC)
    service.list_playback_history.return_value = ([_sample_episode(now)], 20)

    response = client.get("/api/v1/podcasts/episodes/history?page=1&size=10")

    assert response.status_code == 200
    payload = response.json()
    assert payload["next_cursor"] is None
    service.list_playback_history.assert_awaited_once_with(page=1, size=10)

    app.dependency_overrides.pop(get_podcast_episode_service, None)


def test_search_rejects_query_alias():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_search_service] = lambda: service
    client = TestClient(app)

    response = client.get("/api/v1/podcasts/search?query=slow")

    assert response.status_code == 422
    service.search_podcasts.assert_not_awaited()
    app.dependency_overrides.pop(get_podcast_search_service, None)


def test_search_requires_q():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_search_service] = lambda: service
    client = TestClient(app)

    response = client.get("/api/v1/podcasts/search")

    assert response.status_code == 422
    service.search_podcasts.assert_not_awaited()

    app.dependency_overrides.pop(get_podcast_search_service, None)
