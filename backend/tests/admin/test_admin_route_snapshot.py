"""Admin route snapshot checks."""

from app.main import app


def _route_paths() -> set[str]:
    return {route.path for route in app.routes}


def test_admin_routes_snapshot() -> None:
    paths = _route_paths()

    expected_paths = {
        "/api/v1/admin/login",
        "/api/v1/admin/logout",
        "/api/v1/admin/pair",
        "/api/v1/admin/apikeys",
        "/api/v1/admin/apikeys/test",
        "/api/v1/admin/apikeys/create",
        "/api/v1/admin/apikeys/{key_id}/toggle",
        "/api/v1/admin/apikeys/{key_id}/edit",
        "/api/v1/admin/apikeys/{key_id}/delete",
        "/api/v1/admin/api/apikeys/export/json",
        "/api/v1/admin/api/apikeys/import/json",
    }

    assert expected_paths.issubset(paths)
