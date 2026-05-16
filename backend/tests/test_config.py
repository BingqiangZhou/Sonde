from app.core.config import Settings


def test_cors_origins_accept_comma_separated_env_value() -> None:
    settings = Settings(CORS_ORIGINS="http://localhost:3000,http://localhost:8000")

    assert settings.CORS_ORIGINS == ["http://localhost:3000", "http://localhost:8000"]


def test_summary_concurrency_limit_has_default() -> None:
    settings = Settings()

    assert settings.SUMMARY_CONCURRENCY_LIMIT == 4
