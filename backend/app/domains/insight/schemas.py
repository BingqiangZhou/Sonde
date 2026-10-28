"""Insight 域 LLM 输出 schema（pydantic 校验）。"""

from __future__ import annotations

from pydantic import BaseModel, Field, field_validator


class ScoreOutput(BaseModel):
    """scoring.md 输出；category 不在 taxonomy 内时归一到 general。"""

    score: int = Field(ge=0, le=100)
    reason: str = Field(max_length=200)
    category: str
    tags: list[str] = Field(default_factory=list, max_length=8)

    @field_validator("category")
    @classmethod
    def _valid_category(cls, v: str) -> str:
        from app.industry import DEFAULT_CATEGORY
        from app.industry.taxonomy import _BY_KEY

        return v if v in _BY_KEY else DEFAULT_CATEGORY


class WriteOutput(BaseModel):
    """writing.md 输出（prompt 字段为驼峰，schema 用下划线别名承接）。"""

    model_config = {"populate_by_name": True}

    title_zh: str = Field(max_length=60, alias="titleZh")
    summary_zh: str = Field(min_length=10, max_length=600, alias="summaryZh")
    reason_zh: str = Field(max_length=60, alias="reasonZh")


class ReportLeadOutput(BaseModel):
    """report-*-lead.md 输出（同上，驼峰别名）。"""

    model_config = {"populate_by_name": True}

    title: str = Field(max_length=60)
    lead_paragraph: str = Field(min_length=10, max_length=800, alias="leadParagraph")
    highlights: list[str] = Field(min_length=1, max_length=8)
