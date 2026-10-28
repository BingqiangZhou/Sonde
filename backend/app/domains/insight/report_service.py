"""三刊成刊服务（Phase C，逻辑对齐 ts-era reports/daily.ts）。

窗口按 Asia/Shanghai 日历；daily 08:00 / weekly 周一 08:30 / monthly 1 日 08:30。
content JSON 形状对齐 ts-era（Phase D 的 site API 直接复用）。
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.insight.models import AiAnalysis, Report
from app.domains.insight.prompts import render_prompt
from app.domains.insight.provider import build_ai_client_service, chat_json
from app.domains.insight.schemas import ReportLeadOutput
from app.domains.podcast.models import PodcastEpisode, Subscription
from app.industry import category_label, section_order_for
from app.industry.selection import SELECTION
from app.industry.site import SITE


logger = logging.getLogger(__name__)

TIMEZONE = ZoneInfo("Asia/Shanghai")

MAX_ITEMS = {
    "daily": int(SELECTION["max_report_items"]),  # type: ignore[arg-type]
    "weekly": int(SELECTION["max_weekly_items"]),  # type: ignore[arg-type]
    "monthly": int(SELECTION["max_monthly_items"]),  # type: ignore[arg-type]
}


# ── 窗口计算 ────────────────────────────────────────────────────────────────


def report_window(kind: str, report_key: str) -> tuple[datetime, datetime]:
    """report_key → (window_start, window_end)（UTC，边界按沪时区日历）。"""
    if kind == "daily":
        start_local = datetime.strptime(report_key, "%Y-%m-%d").replace(tzinfo=TIMEZONE)
        return start_local.astimezone(ZoneInfo("UTC")), (
            start_local + timedelta(days=1)
        ).astimezone(ZoneInfo("UTC"))
    if kind == "weekly":
        start_local = datetime.strptime(report_key, "%Y-%m-%d").replace(tzinfo=TIMEZONE)
        return start_local.astimezone(ZoneInfo("UTC")), (
            start_local + timedelta(days=7)
        ).astimezone(ZoneInfo("UTC"))
    if kind == "monthly":
        start_local = datetime.strptime(report_key, "%Y-%m").replace(tzinfo=TIMEZONE, day=1)
        if start_local.month == 12:
            next_month = start_local.replace(year=start_local.year + 1, month=1)
        else:
            next_month = start_local.replace(month=start_local.month + 1)
        return start_local.astimezone(ZoneInfo("UTC")), next_month.astimezone(ZoneInfo("UTC"))
    raise ValueError(f"Unknown report kind: {kind}")


def default_report_key(kind: str, *, for_previous: bool = True) -> str:
    """当前时刻对应的默认 report_key（daily=昨天、weekly=上一个周一、monthly=上个月）。"""
    now = datetime.now(TIMEZONE)
    if kind == "daily":
        day = now.date() - timedelta(days=1) if for_previous else now.date()
        return day.isoformat()
    if kind == "weekly":
        days_since_monday = now.weekday()
        monday = (now.date() - timedelta(days=days_since_monday + 7)) if for_previous else (
            now.date() - timedelta(days=days_since_monday)
        )
        return monday.isoformat()
    if kind == "monthly":
        first_this_month = now.date().replace(day=1)
        last_month_end = first_this_month - timedelta(days=1)
        month = last_month_end if for_previous else first_this_month
        return month.strftime("%Y-%m")
    raise ValueError(f"Unknown report kind: {kind}")


def range_label(kind: str, report_key: str) -> str:
    if kind == "monthly":
        return report_key
    start = datetime.strptime(report_key, "%Y-%m-%d").date()
    if kind == "daily":
        return report_key
    return f"{start.isoformat()} ~ {(start + timedelta(days=6)).isoformat()}"


# ── 成刊 ──────────────────────────────────────────────────────────────────


class ReportService:
    """三刊生成与读取。"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def generate_report(
        self, kind: str, report_key: str | None = None, *, force: bool = True
    ) -> Report | None:
        """生成（或强制重生成）一期刊物。窗口内无入选单集时跳过（返回 None）。"""
        if kind not in MAX_ITEMS:
            raise ValueError(f"Unknown report kind: {kind}")
        key = report_key or default_report_key(kind)
        window_start, window_end = report_window(kind, key)

        items = await self._load_selected_items(window_start, window_end, MAX_ITEMS[kind])
        if not items:
            existing = await self.get_report(kind, key)
            if existing is not None:
                logger.info("Report %s/%s window empty, keep existing", kind, key)
                return existing
            logger.info("Report %s/%s window empty, skip", kind, key)
            return None

        material = self._build_material(items)
        lead_prompt, prompt_version = render_prompt(
            f"report-{kind}-lead",
            {
                "siteName": SITE["name"],
                "dateKey": key,
                "rangeLabel": range_label(kind, key),
                "subject": SITE["subject"],
                "items": material,
            },
        )
        lead: ReportLeadOutput = await chat_json(
            self.db,
            prompt=lead_prompt,
            schema=ReportLeadOutput,
            operation="report",
            ai_client=build_ai_client_service(self.db),
        )

        # 分节（taxonomy 序；sections[].items 引用上面 items 的 id）
        sections = [
            {"section": group.section, "items": group.categories}
            for group in section_order_for(item["category"] for item in items)
        ]
        # 每个 section 的 items 改为该分类下的条目 id 列表
        for section in sections:
            ids = [i["id"] for i in items if i["category"] in section["items"]]
            section["items"] = ids

        content = {
            "title": lead.title,
            "leadParagraph": lead.lead_paragraph,
            "highlights": lead.highlights,
            "sections": sections,
            "items": items,  # 平铺条目（ts-era 把 items 嵌在 sections；此处平铺+引用，web 渲染等价）
            "stats": {"total": len(items), "windowStart": window_start.isoformat(), "windowEnd": window_end.isoformat()},
        }

        existing = await self.get_report(kind, key)
        if existing is not None:
            existing.content = content
            existing.model = prompt_version
            existing.revision += 1
            existing.generated_at = datetime.now(ZoneInfo("UTC"))
            await self.db.commit()
            await self.db.refresh(existing)
            return existing

        report = Report(
            kind=kind,
            report_key=key,
            window_start=window_start,
            window_end=window_end,
            content=content,
            model=prompt_version,
            revision=1,
        )
        self.db.add(report)
        await self.db.commit()
        await self.db.refresh(report)
        logger.info("Report %s/%s generated (revision=%d)", kind, key, report.revision)
        return report

    async def _load_selected_items(
        self, window_start: datetime, window_end: datetime, limit: int
    ) -> list[dict]:
        rows = (
            await self.db.execute(
                select(AiAnalysis, PodcastEpisode, Subscription)
                .join(PodcastEpisode, AiAnalysis.episode_id == PodcastEpisode.id)
                .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
                .where(
                    AiAnalysis.is_current.is_(True),
                    AiAnalysis.selected.is_(True),
                    PodcastEpisode.published_at >= window_start,
                    PodcastEpisode.published_at < window_end,
                )
                .order_by(AiAnalysis.score.desc())
                .limit(limit)
            )
        ).all()

        items = []
        for analysis, episode, subscription in rows:
            items.append(
                {
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
            )
        return items

    @staticmethod
    def _build_material(items: list[dict]) -> str:
        """主编 prompt 的材料列表（紧凑、防注入：仅数据）。"""
        lines = []
        for i in items:
            lines.append(
                f"- [{i['score']}分]《{i['titleZh'] or i['originalTitle']}》"
                f"（{i['podcast']}，{i['categoryLabel']}）：{i['summaryZh'] or i['originalTitle']}"
            )
        return "\n".join(lines)

    # ── 读取 ──

    async def get_report(self, kind: str, report_key: str) -> Report | None:
        return (
            await self.db.execute(
                select(Report).where(Report.kind == kind, Report.report_key == report_key)
            )
        ).scalar_one_or_none()

    async def get_latest_report(self, kind: str) -> Report | None:
        return (
            await self.db.execute(
                select(Report)
                .where(Report.kind == kind)
                .order_by(Report.report_key.desc())
                .limit(1)
            )
        ).scalar_one_or_none()

    async def list_report_keys(
        self, kind: str, *, page: int = 1, size: int = 30
    ) -> dict:
        total = (
            await self.db.execute(
                select(func.count()).select_from(Report).where(Report.kind == kind)
            )
        ).scalar_one()
        rows = (
            await self.db.execute(
                select(Report.report_key, Report.revision, Report.generated_at)
                .where(Report.kind == kind)
                .order_by(Report.report_key.desc())
                .limit(size)
                .offset((page - 1) * size)
            )
        ).all()
        return {
            "total": total,
            "page": page,
            "size": size,
            "keys": [
                {"reportKey": r.report_key, "revision": r.revision, "generatedAt": r.generated_at}
                for r in rows
            ],
        }
