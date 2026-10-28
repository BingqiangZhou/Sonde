"""Prompt 渲染器与容错 JSON 提取单测。"""

from __future__ import annotations

import pytest

from app.core.exceptions import ValidationError
from app.domains.insight.json_utils import extract_json_object
from app.domains.insight.prompts import render_prompt


# ── render_prompt ───────────────────────────────────────────────────────────


async def test_render_scoring_with_all_vars():
    text, version = render_prompt(
        "scoring",
        {
            "siteName": "声读",
            "interestProfile": "测试画像",
            "categories": "- tech-ai: 科技",
            "episode": "单集材料",
        },
    )
    assert "声读" in text
    assert "测试画像" in text
    assert "- tech-ai: 科技" in text
    assert "单集材料" in text
    # include 已展开（反幻觉规则内联）
    assert "事实纪律" in text
    # 无残留模板语法
    assert "{{" not in text and "}}" not in text
    assert version.startswith("scoring@") and len(version.split("@")[1]) == 8


async def test_render_missing_variable_is_hard_error():
    with pytest.raises(ValidationError, match="missing variables"):
        render_prompt("scoring", {"siteName": "x"})


async def test_render_missing_include_is_hard_error(tmp_path, monkeypatch):
    # 构造一个引用不存在片段的模板
    import app.domains.insight.prompts as prompts_mod

    bad_dir = tmp_path / "prompts"
    bad_dir.mkdir()
    (bad_dir / "bad.md").write_text("{{> no-such-include}}\n{{x}}", encoding="utf-8")
    monkeypatch.setattr(prompts_mod, "PROMPTS_DIR", bad_dir)
    with pytest.raises(ValidationError, match="not found"):
        render_prompt("bad", {"x": "1"})


async def test_render_self_include_cycle_detected(tmp_path, monkeypatch):
    import app.domains.insight.prompts as prompts_mod

    bad_dir = tmp_path / "prompts"
    bad_dir.mkdir()
    (bad_dir / "a.md").write_text("{{> a}}", encoding="utf-8")
    monkeypatch.setattr(prompts_mod, "PROMPTS_DIR", bad_dir)
    with pytest.raises(ValidationError, match="cycle"):
        render_prompt("a", {})


async def test_prompt_version_changes_with_variables():
    v1, _ = render_prompt("scoring", {"siteName": "s", "interestProfile": "a", "categories": "c", "episode": "e"})
    v2, _ = render_prompt("scoring", {"siteName": "s", "interestProfile": "b", "categories": "c", "episode": "e"})
    assert v1 != v2


# ── extract_json_object ─────────────────────────────────────────────────────


def test_extract_plain_json():
    assert extract_json_object('{"score": 88}') == {"score": 88}


def test_extract_with_think_block():
    content = "<think>思考过程……</think>\n{\"score\": 42}"
    assert extract_json_object(content) == {"score": 42}


def test_extract_fenced_json():
    content = "结果如下：\n```json\n{\"title\": \"x\"}\n```"
    assert extract_json_object(content) == {"title": "x"}


def test_extract_with_surrounding_prose():
    content = '好的，这是我的输出 {"a": 1, "b": [2, 3]} 希望有帮助'
    assert extract_json_object(content) == {"a": 1, "b": [2, 3]}


def test_extract_failure_raises():
    with pytest.raises(ValidationError):
        extract_json_object("完全没有 JSON 的回复")


def test_extract_empty_raises():
    with pytest.raises(ValidationError):
        extract_json_object("   ")
