"""站点公开读服务（Phase D）：episodes / reports / meta。

响应形状与 ts-era /api/site/* 契约对齐（web/app/lib/types.ts），仅读、无鉴权。
"""

from __future__ import annotations

import logging
import re

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError, ValidationError
from app.domains.insight.models import AiAnalysis, Report
from app.domains.podcast.models import PodcastEpisode, Subscription
from app.industry import category_label
from app.industry.selection import SELECTION
from app.industry.site import SITE


logger = logging.getLogger(__name__)

_KEY_PATTERNS = {
    "daily": re.compile(r"^\d{4}-\d{2}-\d{2}$"),
    "weekly": re.compile(r"^\d{4}-\d{2}-\d{2}$"),
    "monthly": re.compile(r"^\d{4}-\d{2}$"),
}

MAX_ITEMS = {
    "daily": int(SELECTION["max_report_items"]),  # type: ignore[arg-type]
    "weekly": int(SELECTION["max_weekly_items"]),  # type: ignore[arg-type]
    "monthly": int(SELECTION["max_monthly_items"]),  # type: ignore[arg-type]
}


def site_meta() -> dict:
    return {
        "name": SITE["name"],
        "nameEn": SITE["name_en"],
        "subject": SITE["subject"],
        "homeTitle": SITE["home_title"],
        "description": SITE["description"],
        "tagline": SITE["tagline"],
    }


def _validate_kind(kind: str) -> None:
    if kind not in _KEY_PATTERNS:
        raise ValidationError(f"Unknown report kind: {kind}")


def _validate_key(kind: str, key: str) -> None:
    if not _KEY_PATTERNS[kind].match(key):
        raise ValidationError(f"Invalid report key for {kind}: {key}")


def _item_from_row(analysis: AiAnalysis, episode: PodcastEpisode, subscription: Subscription) -> dict:
    return {
        "id": episode.id,
        "podcast": subscription.title,
        "originalTitle": episode.title,
        "titleZh": analysis.title_zh,
        "summaryZh": analysis.summary_zh,
        "reasonZh": analysis.reason_zh,
        "category": analysis.category,
        "categoryLabel": category_label(analysis.category),
        "score": analysis.score,
        "url": episode.item_link,
        "publishedAt": episode.published_at.isoformat() if episode.published_at else None,
        "durationSeconds": episode.audio_duration,
    }


class SiteReadService:
    """只读查询：入选时间线 / 全部已分析 / 详情 / 三刊。"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_selected_episodes(self, limit: int = 20) -> dict:
        limit = max(1, min(limit, 100))
        rows = (
            await self.db.execute(
                select(AiAnalysis, PodcastEpisode, Subscription)
                .join(PodcastEpisode, AiAnalysis.episode_id == PodcastEpisode.id)
                .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
                .where(
                    AiAnalysis.is_current.is_(True),
                    AiAnalysis.selected.is_(True),
                    AiAnalysis.title_zh.isnot(None),
                )
                .order_by(PodcastEpisode.published_at.desc())
                .limit(limit)
            )
        ).all()
        return {"items": [_item_from_row(a, e, s) for a, e, s in rows]}

    async def list_all_analyzed(self, page: int = 1, size: int = 50) -> dict:
        page = max(1, page)
        total = (
            await self.db.execute(
                select(func.count())
                .select_from(AiAnalysis)
                .where(AiAnalysis.is_current.is_(True))
            )
        ).scalar_one()
        rows = (
            await self.db.execute(
                select(AiAnalysis, PodcastEpisode, Subscription)
                .join(PodcastEpisode, AiAnalysis.episode_id == PodcastEpisode.id)
                .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
                .where(AiAnalysis.is_current.is_(True))
                .order_by(PodcastEpisode.published_at.desc())
                .limit(size)
                .offset((page - 1) * size)
            )
        ).all()
        items = []
        for a, e, s in rows:
            items.append(
                {
                    **_item_from_row(a, e, s),
                    "reason": a.reason,
                    "selected": a.selected,
                }
            )
        return {
            "items": items,
            "total": total,
            "page": page,
            "pages": (total + size - 1) // size if size else 1,
        }

    async def episode_detail(self, episode_id: int, *, include_transcript: bool = True) -> dict:
        from app.domains.podcast.models import PodcastEpisodeTranscript

        row = (
            await self.db.execute(
                select(AiAnalysis, PodcastEpisode, Subscription)
                .join(PodcastEpisode, AiAnalysis.episode_id == PodcastEpisode.id)
                .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
                .where(
                    AiAnalysis.episode_id == episode_id,
                    AiAnalysis.is_current.is_(True),
                )
            )
        ).first()
        if row is None:
            raise NotFoundError("Episode not found or not analyzed")
        analysis, episode, subscription = row
        item = _item_from_row(analysis, episode, subscription)
        # 播放与转录（App/详情用；web 阅读页不消费这两个字段）
        item["audioUrl"] = episode.audio_url
        if include_transcript:
            ts = (
                await self.db.execute(
                    select(PodcastEpisodeTranscript.transcript_content).where(
                        PodcastEpisodeTranscript.episode_id == episode_id
                    )
                )
            ).scalar_one_or_none()
            item["transcript"] = ts
        item["tags"] = analysis.tags or []
        return {"episode": item}

    # ── reports ──

    async def report(self, kind: str, key: str) -> dict:
        _validate_kind(kind)
        _validate_key(kind, key)
        row = (
            await self.db.execute(
                select(Report).where(Report.kind == kind, Report.report_key == key)
            )
        ).scalar_one_or_none()
        if row is None:
            raise NotFoundError(f"Report {kind}/{key} not found")
        return self._report_to_web(row)

    async def latest_report(self, kind: str) -> dict:
        _validate_kind(kind)
        row = (
            await self.db.execute(
                select(Report)
                .where(Report.kind == kind)
                .order_by(Report.report_key.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        if row is None:
            raise NotFoundError(f"No {kind} report yet")
        return self._report_to_web(row)

    async def report_keys(self, kind: str, page: int = 1, size: int = 30) -> dict:
        _validate_kind(kind)
        page, size = max(1, page), max(1, min(size, 100))
        total = (
            await self.db.execute(
                select(func.count()).select_from(Report).where(Report.kind == kind)
            )
        ).scalar_one()
        rows = (
            await self.db.execute(
                select(Report)
                .where(Report.kind == kind)
                .order_by(Report.report_key.desc())
                .limit(size)
                .offset((page - 1) * size)
            )
        ).scalars().all()
        return {
            "keys": [
                {
                    "reportKey": r.report_key,
                    "generatedAt": r.generated_at.isoformat() if r.generated_at else None,
                    "revision": r.revision,
                }
                for r in rows
            ],
            "total": total,
        }

    @staticmethod
    def _report_to_web(report: Report) -> dict:
        """存储 content（sections 引用条目 id）→ web 形状（sections 内嵌完整条目）。"""
        content = report.content or {}
        items_by_id = {i["id"]: i for i in content.get("items", [])}
        sections = []
        for section in content.get("sections", []):
            entries = []
            for eid in section.get("items", []):
                it = items_by_id.get(eid)
                if it is not None:
                    entries.append({**it, "episodeId": it["id"]})
            sections.append({"section": section.get("section"), "items": entries})
        return {
            "reportKey": report.report_key,
            "generatedAt": report.generated_at.isoformat() if report.generated_at else None,
            "revision": report.revision,
            "content": {
                "title": content.get("title"),
                "leadParagraph": content.get("leadParagraph"),
                "highlights": content.get("highlights", []),
                "sections": sections,
                "stats": {
                    "selected": len(items_by_id),
                    "maxItems": MAX_ITEMS.get(report.kind, 0),
                },
            },
        }
