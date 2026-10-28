"""发现 API（Phase E）：/api/v1/discover —— 后端代理 iTunes，标注已订阅。"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency, require_user
from app.domains.discover.service import DiscoverService
from app.domains.podcast.models import Subscription


router = APIRouter()


def get_discover_service() -> DiscoverService:
    return DiscoverService()


async def _subscribed_feeds(db: AsyncSession) -> set[str]:
    rows = (
        await db.execute(
            select(Subscription.source_url, func.lower(Subscription.source_url))
        )
    ).all()
    return {lower for _, lower in rows}


@router.get("/discover")
async def discover_search(
    q: str = Query(..., min_length=2, max_length=100),
    limit: int = Query(20, ge=1, le=50),
    user_id: int = Depends(require_user),
    service: DiscoverService = Depends(get_discover_service),
    db: AsyncSession = Depends(get_db_session_dependency),
) -> Any:
    data = await service.search(q, limit=limit)
    subscribed = await _subscribed_feeds(db)
    results = [
        p.to_dict(subscribed=(p.feed_url or "").lower() in subscribed)
        for p in data["results"]
    ]
    return {"countries": data["countries"], "total": len(results), "results": results}


@router.get("/discover/charts")
async def discover_charts(
    country: str = Query("CN", min_length=2, max_length=2),
    limit: int = Query(50, ge=1, le=100),
    user_id: int = Depends(require_user),
    service: DiscoverService = Depends(get_discover_service),
    db: AsyncSession = Depends(get_db_session_dependency),
) -> Any:
    data = await service.charts(country, limit=limit)
    subscribed = await _subscribed_feeds(db)
    results = [
        p.to_dict(subscribed=(p.feed_url or "").lower() in subscribed)
        for p in data["results"]
    ]
    return {"country": data["country"], "total": len(results), "results": results}
