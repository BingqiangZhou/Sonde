"""Site 读 API 测试（Phase D 建；Phase G 起端点需登录态）。"""

from __future__ import annotations

from collections.abc import AsyncGenerator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

import app.domains.insight.analyze_service as analyze_mod
import app.domains.insight.report_service as report_mod
import app.domains.podcast.models  # noqa: F401
import app.domains.user.models  # noqa: F401
from app.core.auth import get_db_session_dependency, require_user
from app.core.database import Base
from app.domains.insight.analyze_service import AnalyzeService
from app.domains.insight.models import AiAnalysis
from app.domains.insight.report_service import ReportService
from app.domains.insight.schemas import ReportLeadOutput, ScoreOutput, WriteOutput
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    Subscription,
)


@pytest.fixture
async def env() -> AsyncGenerator[tuple[AsyncSession, AsyncClient], None]:
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)

    from app.main import app

    async with maker() as session:

        async def _override():
            yield session

        app.dependency_overrides[get_db_session_dependency] = _override
        app.dependency_overrides[require_user] = lambda: 1
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            yield session, client
        app.dependency_overrides.pop(get_db_session_dependency, None)
        app.dependency_overrides.pop(require_user, None)
    await engine.dispose()


@pytest.fixture
async def anon_client() -> AsyncGenerator[AsyncClient, None]:
    """未认证客户端：site 端点（Phase G 起挂 require_user）应拒以 401。"""
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)

    from app.main import app

    async with maker() as session:

        async def _override():
            yield session

        app.dependency_overrides[get_db_session_dependency] = _override
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            yield client
        app.dependency_overrides.pop(get_db_session_dependency, None)
    await engine.dispose()


def _llm_outputs():
    async def fake(db, *, prompt, schema, operation, ai_client=None, **kw):
        if schema is ScoreOutput:
            return ScoreOutput(
                score=90, reason="高分理由", category="tech-ai", tags=["AI"]
            )
        if schema is WriteOutput:
            return WriteOutput.model_validate(
                {
                    "titleZh": "中文题",
                    "summaryZh": "中文摘要，足够长。" * 3,
                    "reasonZh": "推荐",
                }
            )
        return ReportLeadOutput.model_validate(
            {
                "title": "刊头",
                "leadParagraph": "导语足够长。" * 3,
                "highlights": ["a", "b"],
            }
        )

    return fake


async def _seed_analyzed(
    db: AsyncSession, *, title: str, published, selected: bool = True
):
    sub = Subscription(
        title=f"播客-{title}",
        source_type="podcast-rss",
        source_url=f"https://{title}.example.com/feed",
        tier="T1",
    )
    db.add(sub)
    await db.flush()
    ep = PodcastEpisode(
        subscription_id=sub.id,
        title=f"{title} 原题",
        audio_url=f"https://{title}.example.com/a.mp3",
        item_link=f"https://{title}.example.com/1",
        published_at=published,
        audio_duration=1800,
    )
    db.add(ep)
    await db.flush()
    db.add(PodcastEpisodeTranscript(episode_id=ep.id, transcript_content="转录" * 100))
    await db.commit()

    fake = _llm_outputs()
    mp = pytest.MonkeyPatch()
    mp.setattr(analyze_mod, "chat_json", fake)
    try:
        if not selected:
            # 直接落一条落选判定（低于门槛）
            from datetime import UTC, datetime

            db.add(
                AiAnalysis(
                    episode_id=ep.id,
                    score=40,
                    selected=False,
                    reason="信息量低",
                    category="general",
                    is_current=True,
                    created_at=datetime.now(UTC),
                )
            )
            await db.commit()
        else:
            await AnalyzeService(db).analyze_episode(ep.id)
    finally:
        mp.undo()
    return ep


async def test_requires_auth(anon_client):
    """Phase G 起 site 端点不再公开：无凭据一律 401。"""
    for path in (
        "/api/v1/site/meta",
        "/api/v1/site/episodes",
        "/api/v1/site/episodes/all",
        "/api/v1/site/episodes/1",
        "/api/v1/site/reports/daily/latest",
    ):
        assert (await anon_client.get(path)).status_code == 401, path


async def test_meta_and_timeline(env):
    from datetime import UTC, datetime, timedelta

    db, client = env
    await _seed_analyzed(db, title="a", published=datetime.now(UTC) - timedelta(days=1))

    meta = (await client.get("/api/v1/site/meta")).json()
    assert meta["name"] == "声读" and meta["nameEn"] == "Sonde"

    feed = (await client.get("/api/v1/site/episodes?limit=10")).json()
    assert len(feed["items"]) == 1
    item = feed["items"][0]
    assert item["titleZh"] == "中文题"
    assert item["categoryLabel"] == "科技与 AI"
    assert item["score"] == 90 and item["durationSeconds"] == 1800


async def test_all_includes_unselected_with_reason(env):
    from datetime import UTC, datetime

    db, client = env
    await _seed_analyzed(db, title="sel", published=datetime.now(UTC), selected=True)
    await _seed_analyzed(db, title="unsel", published=datetime.now(UTC), selected=False)

    feed = (await client.get("/api/v1/site/episodes/all")).json()
    assert feed["total"] == 2
    by_podcast = {i["podcast"]: i for i in feed["items"]}
    assert by_podcast["播客-unsel"]["selected"] is False
    assert by_podcast["播客-unsel"]["reason"] == "信息量低"
    assert by_podcast["播客-sel"]["selected"] is True


async def test_episode_detail_with_audio_and_transcript(env):
    from datetime import UTC, datetime

    db, client = env
    ep = await _seed_analyzed(db, title="d", published=datetime.now(UTC))

    resp = await client.get(f"/api/v1/site/episodes/{ep.id}")
    assert resp.status_code == 200
    detail = resp.json()["episode"]
    assert detail["audioUrl"].endswith(".mp3")
    assert detail["transcript"]
    assert detail["tags"] == ["AI"]

    miss = await client.get("/api/v1/site/episodes/999")
    assert miss.status_code == 404


async def test_reports_flow(env):
    from datetime import UTC, datetime, timedelta

    db, client = env
    yesterday = datetime.now(UTC) - timedelta(days=1)
    await _seed_analyzed(db, title="r1", published=yesterday)

    fake = _llm_outputs()
    mp = pytest.MonkeyPatch()
    mp.setattr(report_mod, "chat_json", fake)
    try:
        report = await ReportService(db).generate_report("daily", force=True)
        assert report is not None
    finally:
        mp.undo()

    latest = (await client.get("/api/v1/site/reports/daily/latest")).json()
    assert latest["content"]["title"] == "刊头"
    assert latest["content"]["stats"]["selected"] == 1
    section = latest["content"]["sections"][0]
    assert (
        section["items"][0]["episodeId"]
        == latest["content"]["sections"][0]["items"][0]["id"]
    )
    assert "summaryZh" in section["items"][0]

    by_key = (
        await client.get(f"/api/v1/site/reports/daily/{latest['reportKey']}")
    ).json()
    assert by_key["reportKey"] == latest["reportKey"]

    archive = (await client.get("/api/v1/site/reports/daily?size=10")).json()
    assert (
        archive["total"] == 1 and archive["keys"][0]["reportKey"] == latest["reportKey"]
    )

    assert (
        await client.get("/api/v1/site/reports/quarterly/latest")
    ).status_code == 400
    # 形状非法 → 400（带斜杠不匹配路由 → 404）；形状合法但不存在 → 404
    assert (
        await client.get("/api/v1/site/reports/daily/2026/10/10")
    ).status_code == 404
    assert (
        await client.get("/api/v1/site/reports/monthly/2026-10-01")
    ).status_code == 400
    assert (
        await client.get("/api/v1/site/reports/daily/2099-01-01")
    ).status_code == 404
