"""单集评分与写作服务（Phase C，逻辑对齐 ts-era pipeline/analyze.ts）。

流程：全文转录 → 评分（10k 截断）→ threshold_for(tier) → 过线才写作（30k 截断）
     → 事务内翻转 is_current 并插入新判定（追加式留史）。
"""

from __future__ import annotations

import logging

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.domains.insight.models import AiAnalysis
from app.domains.insight.prompts import render_prompt
from app.domains.insight.provider import build_ai_client_service, chat_json
from app.domains.insight.schemas import ScoreOutput, WriteOutput
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    Subscription,
)
from app.industry import CATEGORIES, interest_profile_or_default, threshold_for
from app.industry.site import SITE


logger = logging.getLogger(__name__)

SCORE_TRANSCRIPT_LIMIT = 10_000
WRITE_TRANSCRIPT_LIMIT = 30_000


def _categories_table() -> str:
    return "\n".join(f"- {c.key}: {c.label}" for c in CATEGORIES)


def _episode_material(episode: PodcastEpisode, podcast_title: str, transcript: str) -> str:
    duration = f"{episode.audio_duration}s" if episode.audio_duration else "未知"
    return (
        f"播客：{podcast_title}\n"
        f"单集标题：{episode.title}\n"
        f"时长：{duration}\n"
        f"发布时间：{episode.published_at}\n"
        f"\n转录文本：\n{transcript}"
    )


class AnalyzeService:
    """单集 AI 判定。"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def analyze_episode(self, episode_id: int, *, force: bool = False) -> AiAnalysis | None:
        """对单集评分（+过线写作）。无转录 → NotFoundError；已有 current 且非 force → 跳过返回 None。"""
        row = (
            await self.db.execute(
                select(PodcastEpisode, PodcastEpisodeTranscript, Subscription)
                .join(
                    PodcastEpisodeTranscript,
                    PodcastEpisodeTranscript.episode_id == PodcastEpisode.id,
                )
                .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
                .where(PodcastEpisode.id == episode_id)
            )
        ).first()
        if row is None:
            raise NotFoundError(f"Episode {episode_id} has no transcript or subscription")
        episode, transcript_row, subscription = row
        transcript = (transcript_row.transcript_content or "").strip()
        if not transcript:
            raise NotFoundError(f"Episode {episode_id} transcript is empty")

        if not force:
            existing = (
                await self.db.execute(
                    select(AiAnalysis.id).where(
                        AiAnalysis.episode_id == episode_id,
                        AiAnalysis.is_current.is_(True),
                    )
                )
            ).scalar_one_or_none()
            if existing is not None:
                logger.info("Episode %s already analyzed (id=%s), skip", episode_id, existing)
                return None

        podcast_title = subscription.title or "未知播客"
        ai_client = build_ai_client_service(self.db)

        # ── 评分 ──
        score_prompt, score_version = render_prompt(
            "scoring",
            {
                "siteName": SITE["name"],
                "interestProfile": interest_profile_or_default(),
                "categories": _categories_table(),
                "episode": _episode_material(
                    episode, podcast_title, transcript[:SCORE_TRANSCRIPT_LIMIT]
                ),
            },
        )
        scored: ScoreOutput = await chat_json(
            self.db,
            prompt=score_prompt,
            schema=ScoreOutput,
            operation="score",
            ai_client=ai_client,
        )

        tier = getattr(subscription, "tier", None)
        threshold = threshold_for(tier)
        selected = scored.score >= threshold
        logger.info(
            "Episode %s scored %d (tier=%s threshold=%d selected=%s)",
            episode_id,
            scored.score,
            tier,
            threshold,
            selected,
        )

        # ── 过线才写作 ──
        write: WriteOutput | None = None
        write_version: str | None = None
        model_name: str | None = None
        if selected:
            write_prompt, write_version = render_prompt(
                "writing",
                {
                    "siteName": SITE["name"],
                    "interestProfile": interest_profile_or_default(),
                    "podcast": podcast_title,
                    "title": episode.title or "",
                    "transcript": transcript[:WRITE_TRANSCRIPT_LIMIT],
                },
            )
            write = await chat_json(
                self.db,
                prompt=write_prompt,
                schema=WriteOutput,
                operation="write",
                ai_client=ai_client,
            )
            model_name = None  # 单一 model 字段：以评分版本为准，见 prompt_version 组装

        # ── 落库（事务：翻转旧 current → 插新行）──
        await self.db.execute(
            update(AiAnalysis)
            .where(
                AiAnalysis.episode_id == episode_id,
                AiAnalysis.is_current.is_(True),
            )
            .values(is_current=False)
        )
        analysis = AiAnalysis(
            episode_id=episode_id,
            score=scored.score,
            selected=selected,
            reason=scored.reason,
            tags=scored.tags,
            category=scored.category,
            title_zh=write.title_zh if write else None,
            summary_zh=write.summary_zh if write else None,
            reason_zh=write.reason_zh if write else None,
            model=model_name,
            prompt_version=(
                f"{score_version}+{write_version}" if write_version else score_version
            ),
            is_current=True,
        )
        self.db.add(analysis)
        await self.db.commit()
        await self.db.refresh(analysis)
        return analysis

    async def sweep_pending(self, *, limit: int = 20) -> int:
        """兜底：有转录但无 current 判定的单集补评分（返回处理数）。"""
        rows = (
            await self.db.execute(
                select(PodcastEpisode.id)
                .join(
                    PodcastEpisodeTranscript,
                    PodcastEpisodeTranscript.episode_id == PodcastEpisode.id,
                )
                .where(
                    PodcastEpisodeTranscript.transcript_content.isnot(None),
                    ~select(AiAnalysis.id)
                    .where(
                        AiAnalysis.episode_id == PodcastEpisode.id,
                        AiAnalysis.is_current.is_(True),
                    )
                    .exists(),
                )
                .limit(limit)
            )
        ).scalars().all()

        count = 0
        for episode_id in rows:
            try:
                result = await self.analyze_episode(episode_id)
                if result is not None:
                    count += 1
            except Exception:  # noqa: BLE001 —— 单集失败不阻塞 sweep
                logger.exception("Sweep analyze failed for episode %s", episode_id)
        return count
