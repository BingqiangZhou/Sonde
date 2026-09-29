from unittest.mock import AsyncMock

from fastapi.testclient import TestClient

from app.bootstrap import http as http_module
from app.main import app


def test_readiness_endpoint_returns_healthy(monkeypatch):
    monkeypatch.setattr(
        http_module, "check_db_readiness", AsyncMock(return_value={"status": "healthy"})
    )

    client = TestClient(app)
    response = client.get("/api/v1/health/ready")

    assert response.status_code == 200
    assert response.json() == {
        "status": "healthy",
        "db": {"status": "healthy"},
    }


def test_readiness_endpoint_returns_503_when_dependency_unhealthy(monkeypatch):
    monkeypatch.setattr(
        http_module,
        "check_db_readiness",
        AsyncMock(return_value={"status": "unhealthy", "error": "timeout"}),
    )

    client = TestClient(app)
    response = client.get("/api/v1/health/ready")

    assert response.status_code == 503
    payload = response.json()
    assert payload["status"] == "unhealthy"
    assert payload["db"]["status"] == "unhealthy"
