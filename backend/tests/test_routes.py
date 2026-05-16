from app.main import app


def test_podcast_track_routes_are_explicit() -> None:
    methods: set[str] = set()
    for route in app.routes:
        if getattr(route, "path", None) == "/api/v1/podcasts/{podcast_id}/track":
            methods.update(route.methods)

    assert "POST" in methods
    assert "DELETE" in methods
