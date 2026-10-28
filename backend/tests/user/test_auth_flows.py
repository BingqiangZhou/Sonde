"""Auth 路由流测试（Phase B）：注册开关/登录/刷新/登出/隔离。"""

from __future__ import annotations

from unittest.mock import patch

from fastapi import HTTPException
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession


async def _register(c: AsyncClient, email: str, password: str = "password123"):
    return await c.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password},
    )


async def test_register_closed_by_default(client: AsyncClient):
    resp = await _register(client, "alice@example.com")
    assert resp.status_code == 403
    assert "closed" in resp.json()["detail"].lower()


async def test_register_open_then_login_me_refresh_logout(client: AsyncClient):
    with patch("app.domains.user.routes.get_settings") as mock_settings:
        settings = mock_settings.return_value
        settings.REGISTRATION_OPEN = True
        settings.ACCESS_TOKEN_EXPIRE_MINUTES = 30
        settings.REFRESH_TOKEN_EXPIRE_DAYS = 7
        resp = await _register(client, "alice@example.com")
    assert resp.status_code == 201, resp.text
    tokens = resp.json()
    assert tokens["token_type"] == "bearer"
    assert tokens["expires_in"] == 1800

    # 重复注册 → 409
    with patch("app.domains.user.routes.get_settings") as mock_settings:
        mock_settings.return_value.REGISTRATION_OPEN = True
        dup = await _register(client, "alice@example.com")
    assert dup.status_code == 409

    # 登录（email）
    login = await client.post(
        "/api/v1/auth/login",
        json={"email_or_username": "alice@example.com", "password": "password123"},
    )
    assert login.status_code == 200
    access = login.json()["access_token"]

    # 错误密码 → 401
    bad = await client.post(
        "/api/v1/auth/login",
        json={"email_or_username": "alice@example.com", "password": "wrong-pass"},
    )
    assert bad.status_code == 401

    # me：带 token
    me = await client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {access}"})
    assert me.status_code == 200
    assert me.json()["email"] == "alice@example.com"

    # me：无 token → 401
    anon = await client.get("/api/v1/auth/me")
    assert anon.status_code == 401

    # refresh 轮换：新对可用、旧 refresh 失效
    refresh = login.json()["refresh_token"]
    rotated = await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh})
    assert rotated.status_code == 200
    old_again = await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh})
    assert old_again.status_code == 401

    # logout（新 refresh）
    new_refresh = rotated.json()["refresh_token"]
    out = await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": new_refresh},
        headers={"Authorization": f"Bearer {rotated.json()['access_token']}"},
    )
    assert out.status_code == 200
    revoked = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": new_refresh}
    )
    assert revoked.status_code == 401


async def test_forgot_and_reset_password_return_501(client: AsyncClient):
    assert (
        await client.post("/api/v1/auth/forgot-password", json={"email": "a@b.c"})
    ).status_code == 501
    assert (
        await client.post(
            "/api/v1/auth/reset-password", json={"token": "x", "new_password": "y"}
        )
    ).status_code == 501


async def test_cross_user_isolation(
    client: AsyncClient, db_session: AsyncSession
):
    """A 用户看不到 B 的收藏。"""
    # 造一个订阅 + 单集
    from datetime import UTC, datetime

    from sqlalchemy import select

    from app.domains.podcast.models import PodcastEpisode, Subscription

    sub = Subscription(
        title="Test Podcast",
        source_type="podcast-rss",
        source_url="https://example.com/feed.xml",
    )
    db_session.add(sub)
    await db_session.flush()
    ep = PodcastEpisode(
        subscription_id=sub.id,
        title="Episode 1",
        audio_url="https://example.com/ep1.mp3",
        item_link="https://example.com/ep1",
        published_at=datetime.now(UTC),
    )
    db_session.add(ep)
    await db_session.commit()
    episode_id = (
        await db_session.execute(select(PodcastEpisode.id))
    ).scalar_one()

    # 两个用户（走服务层建号，绕过注册开关）
    from app.domains.user.service import AuthenticationService

    service = AuthenticationService(db_session)
    await service.admin_create_user("alice@example.com", "password123")
    await service.admin_create_user("bob@example.com", "password123")

    alice_login = await client.post(
        "/api/v1/auth/login",
        json={"email_or_username": "alice@example.com", "password": "password123"},
    )
    bob_login = await client.post(
        "/api/v1/auth/login",
        json={"email_or_username": "bob@example.com", "password": "password123"},
    )
    alice_token = alice_login.json()["access_token"]
    bob_token = bob_login.json()["access_token"]

    # alice 收藏
    add = await client.put(
        f"/api/v1/podcasts/favorites/{episode_id}",
        headers={"Authorization": f"Bearer {alice_token}"},
    )
    assert add.status_code == 200

    # alice 列表有、bob 列表空
    alice_list = await client.get(
        "/api/v1/podcasts/favorites",
        headers={"Authorization": f"Bearer {alice_token}"},
    )
    bob_list = await client.get(
        "/api/v1/podcasts/favorites",
        headers={"Authorization": f"Bearer {bob_token}"},
    )
    assert alice_list.json()["total"] == 1
    assert alice_list.json()["items"][0]["id"] == episode_id
    assert bob_list.json()["total"] == 0

    # 状态接口 + 删除幂等
    status = await client.get(
        f"/api/v1/podcasts/favorites/{episode_id}/status",
        headers={"Authorization": f"Bearer {alice_token}"},
    )
    assert status.json()["favorited"] is True
    dele = await client.request(
        "DELETE",
        f"/api/v1/podcasts/favorites/{episode_id}",
        headers={"Authorization": f"Bearer {alice_token}"},
    )
    assert dele.status_code == 200
    after = await client.get(
        "/api/v1/podcasts/favorites",
        headers={"Authorization": f"Bearer {alice_token}"},
    )
    assert after.json()["total"] == 0

    # 无 token → 401
    assert (
        await client.get("/api/v1/podcasts/favorites")
    ).status_code == 401


async def test_require_user_rejects_garbage_token(client: AsyncClient):
    resp = await client.get(
        "/api/v1/auth/me", headers={"Authorization": "Bearer not-a-jwt"}
    )
    assert resp.status_code == 401


async def test_ops_api_key_channel_needs_superuser(client: AsyncClient):
    """运维 API Key 通道在无超管时 503。"""
    from unittest.mock import AsyncMock

    with patch(
        "app.core.auth.get_settings"
    ) as mock_settings, patch(
        "app.core.auth._resolve_ops_user_id", new=AsyncMock(side_effect=HTTPException(503, "no superuser"))
    ):
        mock_settings.return_value.API_KEY = "ops-key"
        resp = await client.get(
            "/api/v1/auth/me", headers={"Authorization": "Bearer ops-key"}
        )
    assert resp.status_code == 503
