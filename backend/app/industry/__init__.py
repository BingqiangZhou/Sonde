"""声读（Sonde）industry 定制层。

框架代码读这里做站点定制：站点身份、分类体系、精选门槛与兴趣画像、prompt 模板。
改配置不改代码——所有站点个性都应收敛到本包。
"""

from app.industry.selection import SELECTION, interest_profile_or_default, threshold_for
from app.industry.site import SITE
from app.industry.taxonomy import (
    CATEGORIES,
    DEFAULT_CATEGORY,
    SectionGroup,
    category_label,
    section_of,
    section_order_for,
)


__all__ = [
    "CATEGORIES",
    "DEFAULT_CATEGORY",
    "SELECTION",
    "SITE",
    "SectionGroup",
    "category_label",
    "interest_profile_or_default",
    "section_of",
    "section_order_for",
    "threshold_for",
]
