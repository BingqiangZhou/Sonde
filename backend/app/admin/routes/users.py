"""Admin users management routes（Phase B）。"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse

from app.admin.auth import admin_required
from app.admin.dependencies import get_admin_users_service
from app.admin.routes._shared import get_templates, json_payload, render_admin_template
from app.admin.services import AdminUsersService


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


@router.get("/users", response_class=HTMLResponse)
async def users_page(
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminUsersService = Depends(get_admin_users_service),
    page: int = 1,
):
    context = await service.get_page_context(page=page)
    return render_admin_template(
        templates=templates,
        template_name="users.html",
        request=request,
        user_id=user_id,
        messages=[],
        **context,
    )


@router.post("/users/create")
async def create_user(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
    username: str | None = Form(None),
    is_superuser: bool = Form(False),
    user_id: int = Depends(admin_required),
    service: AdminUsersService = Depends(get_admin_users_service),
):
    try:
        user = await service.create_user(
            email=email, password=password, username=username, is_superuser=is_superuser
        )
        return json_payload(
            {"success": True, "message": f"已创建用户 {user.email}", "id": user.id}
        )
    except HTTPException:
        raise
    except ValueError as exc:
        return json_payload({"success": False, "message": str(exc)}, status_code=400)
    except Exception as exc:
        logger.error("Create user error: %s", exc)
        return json_payload(
            {"success": False, "message": f"创建失败: {exc}"},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@router.post("/users/{user_id_path}/reset-password")
async def reset_password(
    request: Request,
    user_id_path: int,
    new_password: str = Form(...),
    user_id: int = Depends(admin_required),
    service: AdminUsersService = Depends(get_admin_users_service),
):
    try:
        await service.reset_password(user_id_path, new_password)
        return json_payload({"success": True, "message": "密码已重置，该用户全部会话已吊销"})
    except HTTPException:
        raise
    except ValueError as exc:
        return json_payload({"success": False, "message": str(exc)}, status_code=400)
    except Exception as exc:
        logger.error("Reset password error: %s", exc)
        return json_payload(
            {"success": False, "message": f"重置失败: {exc}"},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@router.post("/users/{user_id_path}/toggle")
async def toggle_user(
    request: Request,
    user_id_path: int,
    user_id: int = Depends(admin_required),
    service: AdminUsersService = Depends(get_admin_users_service),
):
    try:
        user = await service.toggle_active(user_id_path)
        return json_payload(
            {"success": True, "message": f"状态已切换为 {user.status}", "status": user.status}
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Toggle user error: %s", exc)
        return json_payload(
            {"success": False, "message": f"操作失败: {exc}"},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@router.post("/users/{user_id_path}/superuser")
async def set_superuser(
    request: Request,
    user_id_path: int,
    value: bool = Form(...),
    user_id: int = Depends(admin_required),
    service: AdminUsersService = Depends(get_admin_users_service),
):
    try:
        user = await service.set_superuser(user_id_path, value)
        return json_payload(
            {"success": True, "message": f"超管已设为 {user.is_superuser}"}
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Set superuser error: %s", exc)
        return json_payload(
            {"success": False, "message": f"操作失败: {exc}"},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
