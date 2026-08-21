"""Admin settings routes module."""

from fastapi import APIRouter, Body, Depends, Request
from fastapi.responses import HTMLResponse

from app.admin.auth import admin_required
from app.admin.dependencies import get_admin_settings_service
from app.admin.routes._shared import get_templates, json_payload, render_admin_template
from app.admin.services import AdminSettingsService


router = APIRouter()
templates = get_templates()


@router.get("/settings", response_class=HTMLResponse)
async def settings_page(
    request: Request,
    user_id: int = Depends(admin_required),
):
    """Display system settings page."""
    return render_admin_template(
        templates=templates,
        template_name="settings.html",
        request=request,
        user_id=user_id,
        messages=[],
    )


@router.get("/settings/api/audio")
async def get_audio_settings(
    _: int = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Get audio processing settings as JSON."""
    return json_payload(await service.get_audio_settings())


@router.post("/settings/api/audio")
async def update_audio_settings(
    request: Request,
    chunk_size_mb: int = Body(..., embed=True),
    max_concurrent_threads: int = Body(..., embed=True),
    user_id: int = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Update audio processing settings."""
    return json_payload(
        await service.save_audio_settings(
            request=request,
            user_id=user_id,
            chunk_size_mb=chunk_size_mb,
            max_concurrent_threads=max_concurrent_threads,
        ),
    )


@router.get("/settings/frequency")
async def get_frequency_settings(
    _: Request,
    ___: int = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Get RSS subscription update frequency settings."""
    return json_payload(await service.get_frequency_settings())


@router.post("/settings/frequency")
async def update_frequency_settings(
    request: Request,
    update_frequency: str = Body(..., embed=True),
    update_time: str | None = Body(None, embed=True),
    update_day: int | None = Body(None, embed=True),
    user_id: int = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Update RSS subscription update frequency settings."""
    return json_payload(
        await service.save_frequency_settings(
            request=request,
            user_id=user_id,
            update_frequency=update_frequency,
            update_time=update_time,
            update_day=update_day,
        ),
    )


@router.get("/settings/api/storage/info")
async def get_storage_info(
    _: int = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Get storage information as JSON."""
    return json_payload(await service.get_storage_info())


@router.get("/settings/api/storage/cleanup/config")
async def get_cleanup_config(
    _: int = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Get auto cleanup configuration as JSON."""
    return json_payload(await service.get_cleanup_config())


@router.post("/settings/api/storage/cleanup/config")
async def update_cleanup_config(
    request: Request,
    enabled: bool = Body(..., embed=True),
    user_id: int = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Update auto cleanup configuration."""
    return json_payload(
        await service.save_cleanup_config(
            request=request,
            user_id=user_id,
            enabled=enabled,
        ),
    )


@router.post("/settings/api/storage/cleanup/execute")
async def execute_cleanup(
    request: Request,
    keep_days: int = Body(1, embed=True),
    user_id: int = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Execute manual cleanup."""
    return json_payload(
        await service.run_cleanup(
            request=request,
            user_id=user_id,
            keep_days=keep_days,
        ),
    )
