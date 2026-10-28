"""站点身份与文案（声读定制层）。

对应 ts-era `industry/site.ts`；v2 中供 site 读 API 与报告 prompt 使用。
"""

from __future__ import annotations


SITE: dict[str, str] = {
    # 站名（中文）
    "name": "声读",
    # 站名（拉丁）
    "name_en": "Sonde",
    # 内容主题词，用于文案模板（如"每天 8 点，一份值得读的{subject}日报"）
    "subject": "播客",
    # 首页 title
    "home_title": "声读 — 每天一份值得读的播客日报",
    # 站点描述（SEO）
    "description": "声读自动订阅播客、转写音频、AI 评分筛选，每天早晨生成一份可读的中文播客日报。",
    # 一句话标语
    "tagline": "把一天的播客，读成一份日报",
    "locale": "zh-CN",
    "contact_email": "",
    "footer_note": "声读 · 个人播客知识库 · 内容版权归原作者所有",
}
