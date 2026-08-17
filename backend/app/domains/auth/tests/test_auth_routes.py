"""End-to-end auth flow tests: register → login → me → rename."""

from __future__ import annotations

import re

from fastapi.testclient import TestClient


GENERATED_USERNAME_RE = re.compile(r"^user_\d{4}[a-z0-9]{4}$")

PASSWORD = "Str0ngPass!"


def register(
    client: TestClient, email: str = "alice@example.com", password: str = PASSWORD
):
    return client.post(
        "/api/v1/auth/register", json={"email": email, "password": password}
    )


def auth_headers(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


class TestRegister:
    def test_register_returns_tokens_and_generated_username(self, client):
        response = register(client)
        assert response.status_code == 201
        tokens = response.json()
        for key in (
            "access_token",
            "refresh_token",
            "token_type",
            "expires_in",
            "expires_at",
            "server_time",
            "session_id",
        ):
            assert tokens[key], f"missing field: {key}"
        assert tokens["token_type"] == "bearer"
        assert tokens["expires_in"] > 0

        me = client.get("/api/v1/auth/me", headers=auth_headers(tokens))
        assert me.status_code == 200
        user = me.json()
        assert user["email"] == "alice@example.com"
        assert GENERATED_USERNAME_RE.match(user["username"])
        assert user["is_verified"] is True
        assert user["is_active"] is True
        assert user["is_superuser"] is False

    def test_register_normalizes_email_to_lowercase(self, client):
        tokens = register(client, email="Alice@Example.COM").json()
        me = client.get("/api/v1/auth/me", headers=auth_headers(tokens))
        assert me.json()["email"] == "alice@example.com"

    def test_register_ignores_client_provided_username(self, client):
        response = client.post(
            "/api/v1/auth/register",
            json={
                "email": "alice@example.com",
                "password": PASSWORD,
                "username": "intruder",
            },
        )
        assert response.status_code == 201
        me = client.get("/api/v1/auth/me", headers=auth_headers(response.json()))
        assert me.json()["username"] != "intruder"

    def test_register_duplicate_email_conflict(self, client):
        assert register(client).status_code == 201
        response = register(client)
        assert response.status_code == 409
        details = response.json()["details"]
        assert details["field"] == "email"
        assert details["message_en"] == "This email is already registered"
        assert details["message_zh"] == "该邮箱已被注册"

    def test_register_weak_password_returns_field_error(self, client):
        response = register(client, password="short")
        assert response.status_code == 422
        errors = response.json()["errors"]
        assert any(e["field"] == "body -> password" for e in errors)

    def test_register_invalid_email_returns_field_error(self, client):
        response = register(client, email="not-an-email")
        assert response.status_code == 422
        errors = response.json()["errors"]
        assert any(e["field"] == "body -> email" for e in errors)


class TestLogin:
    def test_login_by_email(self, client):
        register(client)
        response = client.post(
            "/api/v1/auth/login",
            json={"email_or_username": "alice@example.com", "password": PASSWORD},
        )
        assert response.status_code == 200
        assert response.json()["access_token"]

    def test_login_by_generated_username(self, client):
        tokens = register(client).json()
        username = client.get("/api/v1/auth/me", headers=auth_headers(tokens)).json()[
            "username"
        ]
        response = client.post(
            "/api/v1/auth/login",
            json={"email_or_username": username, "password": PASSWORD},
        )
        assert response.status_code == 200

    def test_login_wrong_password_unauthorized(self, client):
        register(client)
        response = client.post(
            "/api/v1/auth/login",
            json={"email_or_username": "alice@example.com", "password": "Wr0ngPass!"},
        )
        assert response.status_code == 401
        details = response.json()["details"]
        assert details["message_zh"] == "邮箱或密码错误"

    def test_login_unknown_identifier_unauthorized(self, client):
        response = client.post(
            "/api/v1/auth/login",
            json={"email_or_username": "ghost@example.com", "password": PASSWORD},
        )
        assert response.status_code == 401


class TestRefresh:
    def test_refresh_rotates_tokens(self, client):
        tokens = register(client).json()
        response = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": tokens["refresh_token"]},
        )
        assert response.status_code == 200
        rotated = response.json()
        assert rotated["access_token"]
        assert rotated["refresh_token"]
        assert rotated["session_id"] != tokens["session_id"]

        me = client.get("/api/v1/auth/me", headers=auth_headers(rotated))
        assert me.status_code == 200

    def test_refresh_with_garbage_token_unauthorized(self, client):
        response = client.post(
            "/api/v1/auth/refresh", json={"refresh_token": "garbage"}
        )
        assert response.status_code == 401

    def test_refresh_rejects_access_token(self, client):
        tokens = register(client).json()
        response = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": tokens["access_token"]},
        )
        assert response.status_code == 401


class TestLogout:
    def test_logout_is_stateless_ok(self, client):
        response = client.post("/api/v1/auth/logout")
        assert response.status_code == 200
        assert response.json()["detail"] == "Logged out"


class TestMe:
    def test_me_requires_authentication(self, client):
        assert client.get("/api/v1/auth/me").status_code == 401

    def test_me_rejects_garbage_token(self, client):
        response = client.get(
            "/api/v1/auth/me", headers={"Authorization": "Bearer garbage"}
        )
        assert response.status_code == 401

    def test_me_rejects_refresh_token(self, client):
        tokens = register(client).json()
        response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {tokens['refresh_token']}"},
        )
        assert response.status_code == 401


class TestUpdateProfile:
    def test_rename_updates_username(self, client):
        tokens = register(client).json()
        response = client.patch(
            "/api/v1/auth/me",
            json={"username": "newname"},
            headers=auth_headers(tokens),
        )
        assert response.status_code == 200
        assert response.json()["username"] == "newname"

        login = client.post(
            "/api/v1/auth/login",
            json={"email_or_username": "newname", "password": PASSWORD},
        )
        assert login.status_code == 200

    def test_rename_strips_surrounding_whitespace(self, client):
        tokens = register(client).json()
        response = client.patch(
            "/api/v1/auth/me",
            json={"username": "  newname  "},
            headers=auth_headers(tokens),
        )
        assert response.status_code == 200
        assert response.json()["username"] == "newname"

    def test_rename_to_same_value_is_allowed(self, client):
        tokens = register(client).json()
        current = client.get("/api/v1/auth/me", headers=auth_headers(tokens)).json()[
            "username"
        ]
        response = client.patch(
            "/api/v1/auth/me",
            json={"username": current},
            headers=auth_headers(tokens),
        )
        assert response.status_code == 200

    def test_rename_conflict_with_other_user(self, client):
        first = register(client, email="alice@example.com").json()
        second = register(client, email="bob@example.com").json()
        taken = client.get("/api/v1/auth/me", headers=auth_headers(first)).json()[
            "username"
        ]

        response = client.patch(
            "/api/v1/auth/me",
            json={"username": taken},
            headers=auth_headers(second),
        )
        assert response.status_code == 409
        details = response.json()["details"]
        assert details["field"] == "username"
        assert details["message_zh"] == "该名称已被占用"

    def test_rename_too_short_returns_field_error(self, client):
        tokens = register(client).json()
        response = client.patch(
            "/api/v1/auth/me",
            json={"username": "x"},
            headers=auth_headers(tokens),
        )
        assert response.status_code == 422
        errors = response.json()["errors"]
        assert any(e["field"] == "body -> username" for e in errors)
