"""Admin insight 面板服务（Phase D3）：成本、三刊、单集诊断。"""

from __future__ import annotations

from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.insight.models import AiAnalysis, AiReceipt, Report
from app.domains.insight.receipts import receipts_summary
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    Subscription,
    TranscriptionTask,
)


REPORT_KINDS = ("daily", "weekly", "monthly")


class AdminInsightService:
    def __init__(self, db: AsyncSession):
        self.db = db

    # ── 成本页 ──

    async def costs_context(self, days: int = 30) -> dict:
        summary = await receipts_summary(self.db, days)
        recent = (
            await self.db.execute(
                select(AiReceipt).order_by(desc(AiReceipt.id)).limit(50)
            )
        ).scalars().all()
        return {
            "costs_summary": summary,
            "recent_receipts": [
                {
                    "id": r.id,
                    "service": r.service,
                    "operation": r.operation,
                    "model": r.model,
                    "ok": r.ok,
                    "error": (r.error or "")[:120],
                    "duration_ms": r.duration_ms,
                    "audio_seconds": r.audio_seconds,
                    "created_at": r.created_at,
                }
                for r in recent
            ],
        }

    # ── 三刊页 ──

    async def reports_context(self) -> dict:
        rows = (
            await self.db.execute(
                select(Report).order_by(desc(Report.report_key)).limit(60)
            )
        ).scalars().all()
        by_kind: dict[str, list[dict]] = {kind: [] for kind in REPORT_KINDS}
        for r in rows:
            by_kind.setdefault(r.kind, []).append(
                {
                    "report_key": r.report_key,
                    "revision": r.revision,
                    "generated_at": r.generated_at,
                    "items": len((r.content or {}).get("items", [])),
                }
            )
        return {"reports_by_kind": by_kind}

    # ── 单集诊断页 ──

    async def episodes_context(
        self, status: str | None = None, page: int = 1, per_page: int = 30
    ) -> dict:
        base = (
            select(PodcastEpisode, Subscription)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .order_by(desc(PodcastEpisode.id))
        )
        if status:
            base = base.where(PodcastEpisode.status == status)

        total = (
            await self.db.execute(
                select(func.count())
                .select_from(PodcastEpisode)
                .where(
                    PodcastEpisode.status == status if status else True
                )
            )
        ).scalar_one()

        rows = (
            await self.db.execute(base.limit(per_page).offset((page - 1) * per_page))
        ).all()
        episode_ids = [ep.id for ep, _ in rows]

        analyses: dict[int, AiAnalysis] = {}
        if episode_ids:
            arows = (
                await self.db.execute(
                    select(AiAnalysis).where(
                        AiAnalysis.episode_id.in_(episode_ids),
                        AiAnalysis.is_current.is_(True),
                    )
                )
            ).scalars().all()
            analyses = {a.episode_id: a for a in arows}

        tasks: dict[int, TranscriptionTask] = {}
        if episode_ids:
            trows = (
                await self.db.execute(
                    select(TranscriptionTask).where(
                        TranscriptionTask.episode_id.in_(episode_ids)
                    )
                )
            ).scalars().all()
            tasks = {t.episode_id: t for t in trows}

        has_transcript: set[int] = set()
        if episode_ids:
            tset = (
                await self.db.execute(
                    select(PodcastEpisodeTranscript.episode_id).where(
                        PodcastEpisodeTranscript.episode_id.in_(episode_ids)
                    )
                )
            ).scalars().all()
            has_transcript = set(tset)

        items = []
        for ep, sub in rows:
            a = analyses.get(ep.id)
            t = tasks.get(ep.id)
            items.append(
                {
                    "id": ep.id,
                    "podcast": sub.title,
                    "tier": sub.tier,
                    "title": ep.title,
                    "published_at": ep.published_at,
                    "status": ep.status,
                    "transcribe_status": getattr(t, "status", None) if t else None,
                    "transcribe_error": (getattr(t, "error_message", None) or "")[:120] if t else None,
                    "has_transcript": ep.id in has_transcript,
                    "score": a.score if a else None,
                    "selected": a.selected if a else None,
                    "category": a.category if a else None,
                }
            )

        return {
            "episodes": items,
            "total": total,
            "page": page,
            "per_page": per_page,
            "pages": (total + per_page - 1) // per_page,
            "status_filter": status or "",
        }
