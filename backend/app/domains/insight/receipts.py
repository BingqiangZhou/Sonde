"""成本台账：任何付费调用（成功或失败）都落一行 ai_receipts；记账失败绝不影响业务。"""

from __future__ import annotations

import contextlib
import logging

from sqlalchemy import case, func, insert, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.insight.models import AiReceipt


logger = logging.getLogger(__name__)


async def record_receipt(
    db: AsyncSession,
    *,
    service: str,
    operation: str,
    model: str | None = None,
    prompt_tokens: int | None = None,
    completion_tokens: int | None = None,
    audio_seconds: int | None = None,
    ok: bool = True,
    error: str | None = None,
    duration_ms: int | None = None,
    commit: bool = True,
) -> None:
    """写一行台账；异常只记日志。commit=False 时由调用方事务统一提交。"""
    try:
        await db.execute(
            insert(AiReceipt).values(
                service=service,
                operation=operation,
                model=model,
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                audio_seconds=audio_seconds,
                ok=ok,
                error=error[:2000] if error else None,
                duration_ms=duration_ms,
            )
        )
        if commit:
            await db.commit()
    except Exception:  # noqa: BLE001 —— 记账绝不阻塞业务
        logger.exception("Failed to record ai_receipt (service=%s op=%s)", service, operation)
        with contextlib.suppress(Exception):
            await db.rollback()


async def receipts_summary(db: AsyncSession, days: int = 30) -> dict:
    """近 N 天台账汇总（面板成本页数据源）。"""
    cutoff = func.now() - func.make_interval(0, 0, 0, days)
    rows = (
        await db.execute(
            select(
                AiReceipt.service,
                AiReceipt.operation,
                AiReceipt.model,
                func.count().label("calls"),
                func.sum(
                    func.coalesce(AiReceipt.prompt_tokens, 0)
                    + func.coalesce(AiReceipt.completion_tokens, 0)
                ).label("tokens"),
                func.sum(func.coalesce(AiReceipt.audio_seconds, 0)).label("audio_seconds"),
                func.sum(case((AiReceipt.ok.is_(False), 1), else_=0)).label("failures"),
            )
            .where(AiReceipt.created_at >= cutoff)
            .group_by(AiReceipt.service, AiReceipt.operation, AiReceipt.model)
            .order_by(AiReceipt.service, AiReceipt.operation)
        )
    ).all()
    return {
        "days": days,
        "groups": [
            {
                "service": r.service,
                "operation": r.operation,
                "model": r.model,
                "calls": r.calls,
                "tokens": int(r.tokens or 0),
                "audio_seconds": int(r.audio_seconds or 0),
                "failures": int(r.failures or 0),
            }
            for r in rows
        ],
    }
