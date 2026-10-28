"""Admin insight 面板路由（Phase D3）：成本页 / 三刊页 / 单集诊断页。"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Form, Request, status
from fastapi.responses import HTMLResponse

from app.admin.auth import admin_required
from app.admin.dependencies import get_admin_insight_service
from app.admin.routes._shared import (
    get_templates,
    json_payload,
    render_admin_template,
)
from app.admin.services.insight_service import REPORT_KINDS, AdminInsightService


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


@router.get("/costs", response_class=HTMLResponse)
async def costs_page(
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminInsightService = Depends(get_admin_insight_service),
    days: int = 30,
):
    context = await service.costs_context(days=days)
    return render_admin_template(
        templates=templates,
        template_name="costs.html",
        request=request,
        user_id=user_id,
        messages=[],
        **context,
    )


@router.get("/reports", response_class=HTMLResponse)
async def reports_page(
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminInsightService = Depends(get_admin_insight_service),
):
    context = await service.reports_context()
    return render_admin_template(
        templates=templates,
        template_name="reports.html",
        request=request,
        user_id=user_id,
        messages=[],
        **context,
    )


@router.post("/reports/generate")
async def generate_report(
    request: Request,
    kind: str = Form(...),
    report_key: str | None = Form(None),
    user_id: int = Depends(admin_required),
):
    """手动触发生成/重生成（走 Celery，避免 HTTP 长等待）。"""
    if kind not in REPORT_KINDS:
        return json_payload(
            {"success": False, "message": f"非法刊种：{kind}"}, status_code=400
        )
    try:
        from app.domains.insight.tasks import generate_report_task

        generate_report_task.delay(kind, report_key or None)
        return json_payload(
            {"success": True, "message": f"已入队生成 {kind}/{report_key or '默认窗口'}"}
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("Queue report generation failed: %s", exc)
        return json_payload(
            {"success": False, "message": f"入队失败: {exc}"},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@router.get("/episodes", response_class=HTMLResponse)
async def episodes_page(
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminInsightService = Depends(get_admin_insight_service),
    status_filter: str | None = None,
    page: int = 1,
):
    context = await service.episodes_context(status=status_filter, page=page)
    return render_admin_template(
        templates=templates,
        template_name="episodes.html",
        request=request,
        user_id=user_id,
        messages=[],
        **context,
    )
