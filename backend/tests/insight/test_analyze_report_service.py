"""评分/三刊服务层测试（内存 SQLite + mock chat_json）——覆盖 Phase C 验收项。"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

import app.domains.insight.analyze_service as analyze_mod
import app.domains.insight.report_service as report_mod
import app.domains.podcast.models  # noqa: F401
import app.domains.user.models  # noqa: F401
from app.core.database import Base
from app.domains.insight.analyze_service import AnalyzeService
from app.domains.insight.models import AiAnalysis, AiReceipt
from app.domains.insight.report_service import ReportService
from app.domains.insight.schemas import ReportLeadOutput, ScoreOutput, WriteOutput
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    Subscription,
)


SH = __import__("zoneinfo").ZoneInfo("Asia/Shanghai")
UTC_TZ = UTC


async def _seed_episode(db: AsyncSession, *, tier="T2", published: datetime, title="Ep"):
    sub = Subscription(
        title="测试播客",
        source_type="podcast-rss",
        source_url=f"https://example.com/{title}.xml",
        tier=tier,
    )
    db.add(sub)
    await db.flush()
    ep = PodcastEpisode(
        subscription_id=sub.id,
        title=f"{title} 原题",
        audio_url="https://example.com/a.mp3",
        item_link=f"https://example.com/{title}",
        published_at=published,
    )
    db.add(ep)
    await db.flush()
    db.add(
        PodcastEpisodeTranscript(
            episode_id=ep.id, transcript_content="这里是完整转录文本" * 100
        )
    )
    await db.commit()
    return ep


@pytest.fixture
async def db_session():
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as session:
        yield session
    await engine.dispose()


def _score_call(score: int):
    calls = {"n": 0}

    async def fake(db, *, prompt, schema, operation, ai_client=None, **kw):
        calls["n"] += 1
        if schema is ScoreOutput:
            return ScoreOutput(score=score, reason="理由", category="tech-ai", tags=["AI"])
        if schema is WriteOutput:
            return WriteOutput.model_validate(
                {"titleZh": "中文标题", "summaryZh": "这是足够长的中文摘要内容。" * 3, "reasonZh": "值得听"}
            )
        if schema is ReportLeadOutput:
            return ReportLeadOutput.model_validate(
                {"title": "今日刊头", "leadParagraph": "导语段落，足够长。" * 3, "highlights": ["看点一", "看点二"]}
            )
        raise AssertionError(schema)

    return fake, calls


async def test_analyze_selects_and_writes_when_above_threshold(db_session):
    published = datetime.now(UTC)
    ep = await _seed_episode(db_session, tier="T2", published=published)
    fake, calls = _score_call(85)  # T2 门槛 70 → 入选

    monkeypatch = pytest.MonkeyPatch()
    monkeypatch.setattr(analyze_mod, "chat_json", fake)
    try:
        analysis = await AnalyzeService(db_session).analyze_episode(ep.id)
    finally:
        monkeypatch.undo()

    assert analysis is not None
    assert analysis.selected is True
    assert analysis.score == 85
    assert analysis.title_zh == "中文标题"
    assert analysis.prompt_version.startswith("scoring@")


async def test_analyze_no_write_below_threshold(db_session):
    ep = await _seed_episode(db_session, tier="T2", published=datetime.now(UTC))
    fake, calls = _score_call(50)  # 低于 T2 门槛 70 → 落选不写作

    monkeypatch = pytest.MonkeyPatch()
    monkeypatch.setattr(analyze_mod, "chat_json", fake)
    try:
        analysis = await AnalyzeService(db_session).analyze_episode(ep.id)
    finally:
        monkeypatch.undo()

    assert analysis.selected is False
    assert analysis.title_zh is None
    assert calls["n"] == 1  # 只调了评分，没有写作


async def test_analyze_t1_threshold_lower(db_session):
    ep = await _seed_episode(db_session, tier="T1", published=datetime.now(UTC))
    fake, _ = _score_call(65)  # T1 门槛 60 → 入选（T2 会落选）

    monkeypatch = pytest.MonkeyPatch()
    monkeypatch.setattr(analyze_mod, "chat_json", fake)
    try:
        analysis = await AnalyzeService(db_session).analyze_episode(ep.id)
    finally:
        monkeypatch.undo()
    assert analysis.selected is True


async def test_analyze_is_current_rotation_and_skip(db_session):
    ep = await _seed_episode(db_session, published=datetime.now(UTC))
    svc = AnalyzeService(db_session)

    fake, _ = _score_call(80)
    monkeypatch = pytest.MonkeyPatch()
    monkeypatch.setattr(analyze_mod, "chat_json", fake)
    try:
        first = await svc.analyze_episode(ep.id)
        # 幂等跳过
        skipped = await svc.analyze_episode(ep.id)
        assert skipped is None
        # 强制重评 → 新 current，旧翻转
        fake2, _ = _score_call(90)
        monkeypatch.setattr(analyze_mod, "chat_json", fake2)
        second = await svc.analyze_episode(ep.id, force=True)
    finally:
        monkeypatch.undo()

    assert first.score == 80 and second.score == 90
    rows = (
        await db_session.execute(select(AiAnalysis).where(AiAnalysis.episode_id == ep.id))
    ).scalars().all()
    assert len(rows) == 2
    assert sum(1 for r in rows if r.is_current) == 1
    assert second.is_current is True


async def test_sweep_picks_up_unanalyzed(db_session):
    await _seed_episode(db_session, published=datetime.now(UTC))
    fake, _ = _score_call(75)

    monkeypatch = pytest.MonkeyPatch()
    monkeypatch.setattr(analyze_mod, "chat_json", fake)
    try:
        count = await AnalyzeService(db_session).sweep_pending()
    finally:
        monkeypatch.undo()
    assert count == 1


async def test_report_generation_sections_and_revision(db_session):
    # 窗口内三集入选（tech-ai 两集 + business 一集），窗口外一集
    day = datetime(2026, 10, 27, 6, 0, tzinfo=UTC)  # 27 日 14:00 SH
    await _seed_episode(db_session, published=day, title="a")
    await _seed_episode(db_session, published=day + timedelta(hours=1), title="b")
    await _seed_episode(db_session, published=datetime(2026, 10, 1, 6, 0, tzinfo=UTC), title="out")

    fake, _ = _score_call(85)
    monkeypatch = pytest.MonkeyPatch()
    monkeypatch.setattr(analyze_mod, "chat_json", fake)
    try:
        svc = AnalyzeService(db_session)
        for ep in (
            await db_session.execute(select(PodcastEpisode.id).order_by(PodcastEpisode.id))
        ).scalars():
            await svc.analyze_episode(ep)
    finally:
        monkeypatch.undo()

    # business 集强制改分类验证分节归并
    biz = (
        await db_session.execute(
            select(AiAnalysis).where(AiAnalysis.episode_id == 2)
        )
    ).scalar_one()
    biz.category = "business"
    await db_session.commit()

    rfake, _ = _score_call(0)
    monkeypatch2 = pytest.MonkeyPatch()
    monkeypatch2.setattr(report_mod, "chat_json", rfake)
    try:
        rsvc = ReportService(db_session)
        report = await rsvc.generate_report("daily", "2026-10-27", force=True)
        first_revision = report.revision
        # 重生成 revision+1（同一 ORM 行被更新）
        again = await rsvc.generate_report("daily", "2026-10-27", force=True)
    finally:
        monkeypatch2.undo()

    assert report is not None
    content = report.content
    assert content["title"] == "今日刊头"
    assert len(content["items"]) == 2  # 窗口外那集不进
    sections = {s["section"]: s["items"] for s in content["sections"]}
    assert "科技" in sections and "商业" in sections
    assert again.revision == first_revision + 1

    latest = await rsvc.get_latest_report("daily")
    assert latest.report_key == "2026-10-27"
    keys = await rsvc.list_report_keys("daily")
    assert keys["total"] == 1


async def test_report_empty_window_skips(db_session):
    monkeypatch = pytest.MonkeyPatch()
    monkeypatch.setattr(report_mod, "chat_json", AsyncMock())
    try:
        report = await ReportService(db_session).generate_report("daily", "2020-01-01")
    finally:
        monkeypatch.undo()
    assert report is None


async def test_receipts_written_by_chat_json(db_session):
    """chat_json 的记账路径（成功 + 解析失败重试 + 最终失败）。"""
    from app.core.exceptions import ValidationError
    from app.domains.insight.provider import chat_json

    class _FakeClient:
        def __init__(self, content):
            self._content = content

        async def call_with_fallback(self, messages, **kw):
            return self._content, None

    # 成功
    ok_client = _FakeClient('{"score": 77, "reason": "r", "category": "tech-ai", "tags": []}')
    result = await chat_json(
        db_session, prompt="p", schema=ScoreOutput, operation="score", ai_client=ok_client
    )
    assert result.score == 77
    rows = (await db_session.execute(select(AiReceipt))).scalars().all()
    assert len(rows) == 1 and rows[0].ok is True and rows[0].operation == "score"

    # 解析失败 ×3 → ValidationError，且每次尝试都记账（ok=false）
    bad_client = _FakeClient("不是 JSON")
    with pytest.raises(ValidationError):
        await chat_json(
            db_session, prompt="p", schema=ScoreOutput, operation="score", ai_client=bad_client
        )
    rows = (await db_session.execute(select(AiReceipt))).scalars().all()
    assert len(rows) == 4  # 1 成功 + 3 失败尝试
    assert sum(1 for r in rows if not r.ok) == 3
