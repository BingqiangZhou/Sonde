"""Prompt 渲染器（industry/prompts/*.md）。

契约（与 ts-era 对齐）：
- `{{var}}` 变量替换；`{{> file}}` 内联同目录（不含 .md 后缀也可）下的文件；
- 缺失变量/缺失文件 → 硬错误（不允许静默空串）；
- prompt_version = `<name>@<hash8>`，hash 覆盖模板文本 + 全部变量值，随结果入库。
"""

from __future__ import annotations

import hashlib
import re
from pathlib import Path

from app.core.exceptions import ValidationError


PROMPTS_DIR = Path(__file__).resolve().parent.parent.parent / "industry" / "prompts"

_VAR_RE = re.compile(r"\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}")
_INCLUDE_RE = re.compile(r"\{\{\s*>\s*([a-zA-Z0-9_./-]+?)\s*\}\}")


def _resolve_include(name: str) -> str:
    """按名称找 prompt 片段；允许带或不带 .md 后缀。缺失即硬错误。"""
    base = PROMPTS_DIR / name
    for candidate in (base, base.with_suffix(".md") if base.suffix != ".md" else base):
        if candidate.is_file():
            return candidate.read_text(encoding="utf-8")
    raise ValidationError(f"Prompt include not found: {name} (in {PROMPTS_DIR})")


def render_prompt(name: str, variables: dict[str, str]) -> tuple[str, str]:
    """渲染模板；返回 (rendered_text, prompt_version)。

    include 递归展开（带环检测）；变量在 include 展开后替换。
    """
    path = PROMPTS_DIR / f"{name}.md"
    if not path.is_file():
        raise ValidationError(f"Prompt template not found: {name}.md (in {PROMPTS_DIR})")

    text = path.read_text(encoding="utf-8")

    # 展开 include（单层：被包含文件中的 {{>}} 不再递归展开——
    # 规则文件的说明注释含有字面量 {{> ...}}，递归会误判自引用）
    def _sub(m: re.Match[str]) -> str:
        inc = m.group(1)
        if inc == name:
            raise ValidationError(f"Prompt include cycle: {name} -> {inc}")
        return _resolve_include(inc)

    text = _INCLUDE_RE.sub(_sub, text)

    # 校验变量齐全后替换
    required = set(_VAR_RE.findall(text))
    missing = required - set(variables)
    if missing:
        raise ValidationError(
            f"Prompt '{name}' missing variables: {', '.join(sorted(missing))}"
        )
    rendered = _VAR_RE.sub(lambda m: str(variables[m.group(1)]), text)

    version_hash = hashlib.sha256(
        (text + "\x00" + "\x00".join(f"{k}={variables[k]}" for k in sorted(variables))).encode(
            "utf-8"
        )
    ).hexdigest()[:8]
    return rendered, f"{name}@{version_hash}"


def prompt_file_exists(name: str) -> bool:
    return (PROMPTS_DIR / f"{name}.md").is_file()
