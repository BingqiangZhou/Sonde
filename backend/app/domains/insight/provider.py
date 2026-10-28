"""chat_json：结构化 LLM 调用（渲染 prompt → call_with_fallback → 容错 JSON → pydantic 校验 → 记账）。

复用 core/ai_client 的 AIClientService（模型回退链/重试），post_process 关闭
sanitize_html 以保住 JSON 原文（仅剥 <think>）。tokens 用量在 call_with_fallback
中不可得，首版记 0（台账仍有 model/ok/耗时）。
"""

from __future__ import annotations

import logging
import time
from typing import TypeVar

from pydantic import BaseModel
from pydantic import ValidationError as PydanticValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.ai_client import AIClientService
from app.core.exceptions import ValidationError
from app.core.utils import filter_thinking_content
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.ai.services.model_config_service import AIModelSecurityService
from app.domains.insight.json_utils import extract_json_object
from app.domains.insight.receipts import record_receipt


logger = logging.getLogger(__name__)

T = TypeVar("T", bound=BaseModel)

PARSE_RETRIES = 2  # JSON 解析/校验失败时整体重试次数


def build_ai_client_service(db: AsyncSession) -> AIClientService:
    return AIClientService(
        repo=AIModelConfigRepository(db),
        security_service=AIModelSecurityService(db),
    )


def _raw_content(content: str) -> str:
    """仅剥思考内容，不做 HTML 清洗（保留 JSON 原文）。"""
    return filter_thinking_content(content)


async def chat_json(
    db: AsyncSession,
    *,
    prompt: str,
    schema: type[T],
    operation: str,
    ai_client: AIClientService | None = None,
    max_tokens: int | None = None,
) -> T:
    """调用 LLM 并解析为 schema 实例；解析/校验失败重试，仍失败则 ValidationError。

    每次尝试（含失败）都写 ai_receipts。
    """
    service = ai_client or build_ai_client_service(db)
    last_error: Exception | None = None

    for attempt in range(PARSE_RETRIES + 1):
        started = time.monotonic()
        try:
            content, model_config = await service.call_with_fallback(
                [{"role": "user", "content": prompt}],
                max_tokens=max_tokens,
                operation_name=f"insight-{operation}",
                post_process=_raw_content,
            )
        except Exception as exc:  # noqa: BLE001 —— 任何调用失败都记账后抛出
            await record_receipt(
                db,
                service="llm",
                operation=operation,
                ok=False,
                error=f"{type(exc).__name__}: {exc}",
                duration_ms=int((time.monotonic() - started) * 1000),
            )
            raise

        model_name = getattr(model_config, "model_id", None) if model_config else None
        duration_ms = int((time.monotonic() - started) * 1000)

        try:
            payload = extract_json_object(content)
            parsed = schema.model_validate(payload)
        except (
            ValidationError,
            PydanticValidationError,
        ) as exc:
            await record_receipt(
                db,
                service="llm",
                operation=operation,
                model=model_name,
                ok=False,
                error=f"parse failed (attempt {attempt + 1}): {exc}",
                duration_ms=duration_ms,
            )
            last_error = exc
            logger.warning(
                "chat_json parse failed (op=%s attempt=%d): %s", operation, attempt + 1, exc
            )
            continue

        await record_receipt(
            db,
            service="llm",
            operation=operation,
            model=model_name,
            duration_ms=duration_ms,
        )
        return parsed

    raise ValidationError(
        f"chat_json failed after {PARSE_RETRIES + 1} attempts (op={operation}): {last_error}"
    )
