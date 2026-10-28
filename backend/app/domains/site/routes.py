"""站点公开读 API（Phase D）：/api/v1/site/*，无鉴权。

形状契约见 web/app/lib/types.ts（自 ts-era 平移）。
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency
from app.domains.site.service import SiteReadService, site_meta


router = APIRouter()


def get_site_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> SiteReadService:
    return SiteReadService(db)


@router.get("/meta")
async def meta() -> Any:
    return site_meta()


@router.get("/episodes")
async def episodes(
    limit: int = Query(20, ge=1, le=100),
    service: SiteReadService = Depends(get_site_service),
) -> Any:
    return await service.list_selected_episodes(limit)


@router.get("/episodes/all")
async def all_episodes(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=100),
    service: SiteReadService = Depends(get_site_service),
) -> Any:
    return await service.list_all_analyzed(page, size)


@router.get("/episodes/{episode_id}")
async def episode_detail(
    episode_id: int,
    service: SiteReadService = Depends(get_site_service),
) -> Any:
    return await service.episode_detail(episode_id)


@router.get("/reports/{kind}/latest")
async def report_latest(
    kind: str,
    service: SiteReadService = Depends(get_site_service),
) -> Any:
    return await service.latest_report(kind)


@router.get("/reports/{kind}")
async def report_keys(
    kind: str,
    page: int = Query(1, ge=1),
    size: int = Query(30, ge=1, le=100),
    service: SiteReadService = Depends(get_site_service),
) -> Any:
    return await service.report_keys(kind, page, size)


@router.get("/reports/{kind}/{report_key}")
async def report_by_key(
    kind: str,
    report_key: str,
    service: SiteReadService = Depends(get_site_service),
) -> Any:
    return await service.report(kind, report_key)
