"""LLM 输出的容错 JSON 提取（对齐 ts-era util/json.ts）。

级联：剥 <think> → 直接 json.loads → ```json 围栏 → 普通围栏 → 首个 { 到末个 } 的子串。
"""

from __future__ import annotations

import json
import re

from app.core.exceptions import ValidationError


_THINK_RE = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)
_FENCE_JSON_RE = re.compile(r"```(?:json|JSON)\s*\n(.*?)```", re.DOTALL)
_FENCE_ANY_RE = re.compile(r"```\s*\n(.*?)```", re.DOTALL)


def extract_json_object(content: str) -> dict:
    """从 LLM 输出提取第一个 JSON 对象；全部失败抛 ValidationError。"""
    if not content or not content.strip():
        raise ValidationError("Empty LLM response")

    text = _THINK_RE.sub("", content).strip()

    candidates: list[str] = [text]
    candidates.extend(m.group(1).strip() for m in _FENCE_JSON_RE.finditer(text))
    candidates.extend(m.group(1).strip() for m in _FENCE_ANY_RE.finditer(text))

    # 首个 { 到末个 } 的子串（容忍前后杂文）
    first = text.find("{")
    last = text.rfind("}")
    if first != -1 and last > first:
        candidates.append(text[first : last + 1])

    for candidate in candidates:
        try:
            parsed = json.loads(candidate)
        except (json.JSONDecodeError, ValueError):
            continue
        if isinstance(parsed, dict):
            return parsed

    raise ValidationError(f"Failed to parse LLM JSON output: {content[:200]!r}")
