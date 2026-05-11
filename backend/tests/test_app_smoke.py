from app.core.config import Settings


def test_cors_origins_accepts_comma_separated_env(monkeypatch):
    monkeypatch.setenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:8000")

    assert Settings().CORS_ORIGINS == [
        "http://localhost:3000",
        "http://localhost:8000",
    ]


def test_app_imports():
    from app.main import app

    assert app.title == "PodcastInsight"
