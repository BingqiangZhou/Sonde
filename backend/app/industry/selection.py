"""精选门槛与兴趣画像（声读定制层）。

对应 ts-era `industry/selection.ts`：
- thresholds：按源分级的入选门槛。LLM 为单集打 0-100 注意力价值分，
  score >= thresholds[source.tier] 才会进入写作与日报。
- interest_profile：兴趣画像，注入评分 prompt 的"听众相关性"维度；
  留空则使用通用标准。
"""

from __future__ import annotations


SELECTION: dict[str, object] = {
    "thresholds": {"T1": 60, "T2": 70},
    # 未配置 tier 的源使用的默认门槛
    "default_threshold": 70,
    # 每日日报最多收录条目数
    "max_report_items": 10,
    # 周报最多收录条目数（从上一周入选单集中取分数最高者）
    "max_weekly_items": 16,
    # 月报最多收录条目数
    "max_monthly_items": 24,
    # 兴趣画像（中文，一句话到一段话均可）
    "interest_profile": "",
}

_THRESHOLDS: dict[str, int] = SELECTION["thresholds"]  # type: ignore[assignment]
_DEFAULT_THRESHOLD: int = SELECTION["default_threshold"]  # type: ignore[assignment]


def threshold_for(tier: str | None) -> int:
    if tier is None:
        return _DEFAULT_THRESHOLD
    return _THRESHOLDS.get(tier, _DEFAULT_THRESHOLD)


def interest_profile_or_default() -> str:
    """兴趣画像；留空时返回通用标准话术（供评分 prompt 注入）。"""
    profile = str(SELECTION["interest_profile"]).strip()
    if profile:
        return profile
    return "听众是关注科技、商业与人文的普通话听众，偏好信息密度高、有新知增量的内容。"
