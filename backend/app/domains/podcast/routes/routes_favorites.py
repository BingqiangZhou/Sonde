"""收藏同步 API（Phase B）：GET/PUT/DELETE /api/v1/podcasts/favorites。"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency, require_user
from app.domains.podcast.services.favorites_service import FavoritesService


router = APIRouter()


def get_favorites_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> FavoritesService:
    return FavoritesService(db)


@router.get("/favorites")
async def list_favorites(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=100),
    user_id: int = Depends(require_user),
    service: FavoritesService = Depends(get_favorites_service),
) -> Any:
    """当前用户收藏单集列表（收藏时间倒序）。"""
    return await service.list_favorites(user_id, page, size)


@router.put("/favorites/{episode_id}", status_code=200)
async def add_favorite(
    episode_id: int,
    user_id: int = Depends(require_user),
    service: FavoritesService = Depends(get_favorites_service),
) -> Any:
    """收藏单集（幂等）。"""
    await service.add_favorite(user_id, episode_id)
    return {"episode_id": episode_id, "favorited": True}


@router.delete("/favorites/{episode_id}", status_code=200)
async def remove_favorite(
    episode_id: int,
    user_id: int = Depends(require_user),
    service: FavoritesService = Depends(get_favorites_service),
) -> Any:
    """取消收藏（幂等）。"""
    await service.remove_favorite(user_id, episode_id)
    return {"episode_id": episode_id, "favorited": False}


@router.get("/favorites/{episode_id}/status")
async def favorite_status(
    episode_id: int,
    user_id: int = Depends(require_user),
    service: FavoritesService = Depends(get_favorites_service),
) -> Any:
    """单集收藏状态（详情页星标初始值）。"""
    return {"episode_id": episode_id, "favorited": await service.is_favorite(user_id, episode_id)}
