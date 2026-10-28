"""Discover 服务与路由测试（Phase E；HTTP 全 mock）。"""

from __future__ import annotations

from collections.abc import AsyncGenerator
from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

import app.domains.podcast.models  # noqa: F401
import app.domains.user.models  # noqa: F401
from app.core.auth import get_db_session_dependency
from app.core.database import Base
from app.domains.discover.service import DiscoverService
from app.domains.podcast.models import Subscription


class _FakeResp:
    def __init__(self, payload, status=200):
        self._payload = payload
        self.status = status

    async def json(self, content_type=None):
        return self._payload

    async def text(self):
        return str(self._payload)

    async def __aenter__(self):
        return self

    async def __aexit__(self, *a):
        return False


class _FakeSession:
    """按 URL 前缀路由；search 类请求按 params.country 返回 {"results": [...]}。"""

    def __init__(self, router):
        self.router = router

    def get(self, url, params=None, proxy=None):
        if "search" in url:
            country = (params or {}).get("country", "CN")
            return _FakeResp({"results": self.router["search"].get(country, [])})
        for prefix, payload in self.router.items():
            if prefix in url:
                return _FakeResp(payload)
        return _FakeResp({}, status=404)

    async def close(self):
        pass


def _search_payload(store_hits: dict[str, list[dict]]) -> dict[str, list]:
    return {c: [{"collectionId": i, "collectionName": f"Pod {i}", "artistName": "A",
                 "primaryGenreName": "Tech", "trackCount": 10,
                 "artworkUrl100": f"https://img/{i}.jpg", "feedUrl": f"https://feed/{i}.xml",
                 "collectionViewUrl": f"https://apple/{i}"} for i in ids]
            for c, ids in store_hits.items()}


async def test_search_merges_by_feed_url_across_countries():
    payload = _search_payload({"CN": [1, 2], "US": [2, 3]})
    svc = DiscoverService()
    DiscoverService.clear_cache()
    with patch.object(svc, "_session", AsyncMock(return_value=_FakeSession({"search": payload}))), \
         patch("app.domains.discover.service.get_settings") as mock_settings:
        mock_settings.return_value.ITUNES_COUNTRIES = "CN,US"
        mock_settings.return_value.ITUNES_PROXY_URL = ""
        mock_settings.return_value.ITUNES_DNS = ""
        mock_settings.return_value.ITUNES_TIMEOUT_SECONDS = 5.0
        data = await svc.search("term", limit=10)

    assert data["countries"] == ["CN", "US"]
    assert len(data["results"]) == 3
    by_name = {p.name: p for p in data["results"]}
    # feed 2 命中两国 → stores 合并
    assert sorted(by_name["Pod 2"].stores) == ["CN", "US"]
    assert by_name["Pod 1"].stores == ["CN"]


async def test_search_country_failure_tolerated():
    payload = _search_payload({"CN": [1]})
    svc = DiscoverService()
    DiscoverService.clear_cache()

    class _FlakySession(_FakeSession):
        def __init__(self):
            super().__init__({"search": payload})
            self.calls = 0

        def get(self, url, params=None, proxy=None):
            self.calls += 1
            if params and params.get("country") == "US":
                raise RuntimeError("boom")
            return _FakeResp({"results": self.router["search"].get("CN", [])})

    flaky = _FlakySession()
    with patch.object(svc, "_session", AsyncMock(return_value=flaky)), \
         patch("app.domains.discover.service.get_settings") as mock_settings:
        mock_settings.return_value.ITUNES_COUNTRIES = "CN,US"
        mock_settings.return_value.ITUNES_PROXY_URL = ""
        mock_settings.return_value.ITUNES_DNS = ""
        mock_settings.return_value.ITUNES_TIMEOUT_SECONDS = 5.0
        data = await svc.search("term")
    assert data["failed"] == ["US"]
    assert len(data["results"]) == 1


async def test_short_term_rejected():
    from app.core.exceptions import ValidationError

    with pytest.raises(ValidationError):
        await DiscoverService().search("a")


async def test_charts_rank_and_lookup_feedurl():
    charts_payload = {"feed": {"results": [
        {"id": 11, "name": "Chart A", "artistName": "X", "artworkUrl100": "https://a.jpg"},
        {"id": 22, "name": "Chart B", "artistName": "Y", "artworkUrl100": "https://b.jpg"},
    ]}}
    lookup_payload = {"results": [
        {"collectionId": 11, "kind": "podcast", "feedUrl": "https://feed/11.xml"},
        {"collectionId": 22, "kind": "podcast", "feedUrl": "https://feed/22.xml"},
    ]}
    svc = DiscoverService()
    DiscoverService.clear_cache()
    with patch.object(svc, "_session", AsyncMock(return_value=_FakeSession(
            {"podcasts/top": charts_payload, "lookup": lookup_payload}))):
        data = await svc.charts("CN", limit=10)
    assert [p.rank for p in data["results"]] == [1, 2]
    assert data["results"][0].feed_url == "https://feed/11.xml"


# ── 路由层（subscribed 标注 + 鉴权） ─────────────────────────────────────


@pytest.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    from app.main import app

    async def _override():
        yield db_session

    app.dependency_overrides[get_db_session_dependency] = _override
    from app.core.auth import require_user

    app.dependency_overrides[require_user] = lambda: 1
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    app.dependency_overrides.pop(get_db_session_dependency, None)
    app.dependency_overrides.pop(require_user, None)


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as session:
        yield session
    await engine.dispose()


async def test_discover_routes_mark_subscribed(db_session, client):
    db_session.add(
        Subscription(
            title="已订阅",
            source_type="podcast-rss",
            source_url="https://feed/1.xml",
        )
    )
    await db_session.commit()

    DiscoverService.clear_cache()
    with patch.object(DiscoverService, "search", AsyncMock(return_value={
            "countries": ["CN"], "failed": [],
            "results": [
                __import__("app.domains.discover.service", fromlist=["DiscoveredPodcast"]).DiscoveredPodcast(
                    collection_id=1, name="Pod 1", feed_url="https://feed/1.xml", stores=["CN"],
                ),
                __import__("app.domains.discover.service", fromlist=["DiscoveredPodcast"]).DiscoveredPodcast(
                    collection_id=2, name="Pod 2", feed_url="https://feed/2.xml", stores=["CN"],
                ),
            ]})):
        resp = await client.get("/api/v1/discover", params={"q": "term"})
    assert resp.status_code == 200
    body = resp.json()
    by_name = {r["name"]: r for r in body["results"]}
    assert by_name["Pod 1"]["subscribed"] is True
    assert by_name["Pod 2"]["subscribed"] is False
