"""日报分节与分类（声读定制层）。

评分/写作阶段为单集选择一个 category key；日报按 section 分节呈现。
对应 ts-era `industry/taxonomy.ts`。
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from typing import NamedTuple


class Category(NamedTuple):
    """一个分类：key 用于存储，label 中文标签，section 日报分节。"""

    key: str
    label: str
    section: str


CATEGORIES: list[Category] = [
    Category("tech-ai", "科技与 AI", "科技"),
    Category("business", "商业与财经", "商业"),
    Category("society-culture", "文化与社会", "文化与生活"),
    Category("life-growth", "生活与成长", "文化与生活"),
    Category("general", "综合", "其他"),
]

DEFAULT_CATEGORY = "general"

_BY_KEY = {c.key: c for c in CATEGORIES}


@dataclass(frozen=True)
class SectionGroup:
    """日报中的一节：section 名 + 归入该节的 category keys。"""

    section: str
    categories: list[str]


def category_label(key: str | None) -> str:
    return _BY_KEY[key].label if key in _BY_KEY else "综合"


def section_of(key: str) -> str:
    return _BY_KEY[key].section if key in _BY_KEY else "其他"


def section_order_for(category_keys: Iterable[str]) -> list[SectionGroup]:
    """按配置的 section 顺序归并分类；未匹配的 key 归入"其他"。"""
    sections: dict[str, list[str]] = {}
    for key in category_keys:
        section = section_of(key)
        bucket = sections.setdefault(section, [])
        if key not in bucket:
            bucket.append(key)

    # 配置顺序（去重），未出现在配置中的 section 排最后
    ordered: list[str] = []
    for c in CATEGORIES:
        if c.section not in ordered:
            ordered.append(c.section)

    def rank(section: str) -> int:
        return ordered.index(section) if section in ordered else len(ordered)

    return [
        SectionGroup(section, sections[section]) for section in sorted(sections, key=rank)
    ]
