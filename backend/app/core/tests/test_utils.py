"""Unit tests for utility functions.
工具函数单元测试
"""

import pytest

from app.core.utils import filter_thinking_content


@pytest.mark.parametrize(
    ("input_text", "expected"),
    [
        # Both tag flavors are stripped (two separate regexes in source).
        ("<thinking>Let me think</thinking>Hello, world!", "Hello, world!"),
        ("<think>Let me think</think>The answer", "The answer"),
        # Multiline thinking blocks (DOTALL behaviour).
        (
            "<thinking>\n    This is a multiline\n    thinking process\n    </thinking>\n    The actual answer is here.",
            "The actual answer is here.",
        ),
        # Multiple segments in one response.
        (
            "<think>First thought</think>Part 1<think>Second thought</think>Part 2",
            "Part 1Part 2",
        ),
        # Content that is only a thinking block collapses to empty.
        ("<thinking>This is only thinking</thinking>", ""),
        # Case-insensitive matching.
        ("<THINKING>Upper case tag</THINKING>The content", "The content"),
        # Mixed tag kinds in one response.
        (
            "<thinking>First</thinking>Part 1<think>Second</think>Part 2",
            "Part 1Part 2",
        ),
        # Special characters inside the thinking block.
        (
            "<thinking>This has <special> characters & symbols</thinking>Normal text",
            "Normal text",
        ),
    ],
)
def test_filters_thinking_segments(input_text: str, expected: str):
    assert filter_thinking_content(input_text) == expected


def test_content_without_tags_unchanged():
    input_text = "Just a normal response without thinking tags."
    assert filter_thinking_content(input_text) == input_text


def test_none_input_returns_none():
    assert filter_thinking_content(None) is None


def test_empty_string_returns_empty():
    assert filter_thinking_content("") == ""


def test_preserves_internal_whitespace():
    input_text = "<thinking>Thoughts</thinking>\nLine 1\n\nLine 2"
    assert filter_thinking_content(input_text) == "Line 1\n\nLine 2"


def test_preserves_chinese_punctuation():
    """Normal Chinese punctuation is NOT filtered / 正常的中文标点不被过滤."""
    input_text = "这是一个测试、包含逗号。还有句号。"
    assert filter_thinking_content(input_text) == input_text


def test_complex_response_structure_preserved():
    input_text = """<thinking>
Let me analyze this question.
</thinking>

Based on my analysis:
1. Item one
2. Item two

Conclusion."""
    expected = """Based on my analysis:
1. Item one
2. Item two

Conclusion."""
    assert filter_thinking_content(input_text) == expected.strip()
