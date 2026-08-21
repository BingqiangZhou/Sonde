"""HTTP and middleware bootstrap."""

import logging

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.core.config import get_settings
from app.core.database import check_db_readiness
from app.core.exceptions import setup_exception_handlers
from app.core.middleware import RequestIDMiddleware, RequestLoggingMiddleware
from app.core.rate_limit import limiter
from app.core.redis import get_shared_redis


logger = logging.getLogger(__name__)


def configure_middlewares(app: FastAPI) -> None:
    """Register middleware stack."""
    settings = get_settings()

    # Rate limiting
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    app.add_middleware(SlowAPIMiddleware)

    # Request-id wraps request logging (Starlette runs the last-added
    # middleware outermost) so access/error log lines carry the same id.
    app.add_middleware(RequestLoggingMiddleware, slow_threshold=5.0)
    app.add_middleware(RequestIDMiddleware)
    logger.debug("Request logging middleware enabled")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_HOSTS,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
        allow_headers=[
            "Authorization",
            "Content-Type",
            "Accept",
            "X-Requested-With",
            "X-API-Key",
        ],
    )


def configure_exception_handlers(app: FastAPI) -> None:
    """Register shared and admin-specific exception handlers."""
    setup_exception_handlers(app)
    register_admin_http_exception_handler(app)


def register_admin_http_exception_handler(app: FastAPI) -> None:
    """Register admin-specific redirects and HTML error rendering.

    This handler extends the global http_exception_handler from app.core.exceptions
    with admin-specific behavior (redirects, HTML error pages). For non-admin routes,
    it delegates to the global custom handler to ensure consistent JSON error responses.
    """
    from app.core.exceptions import (
        http_exception_handler as global_http_exception_handler,
    )

    @app.exception_handler(HTTPException)
    async def custom_http_exception_handler(request, exc):
        is_admin_request = request.url.path.startswith("/api/v1/admin/")

        if exc.status_code == status.HTTP_307_TEMPORARY_REDIRECT:
            return RedirectResponse(
                url=exc.headers.get("Location", "/api/v1/admin/login"),
                status_code=status.HTTP_303_SEE_OTHER,
            )

        if (
            is_admin_request
            and exc.status_code == status.HTTP_401_UNAUTHORIZED
            and request.url.path != "/api/v1/admin/login"
        ):
            return RedirectResponse(
                url="/api/v1/admin/login",
                status_code=status.HTTP_303_SEE_OTHER,
            )

        if is_admin_request and exc.status_code >= 400:
            from fastapi.templating import Jinja2Templates

            templates = Jinja2Templates(directory="app/admin/templates")
            return templates.TemplateResponse(
                "error.html",
                {
                    "request": request,
                    "error_message": exc.detail
                    if isinstance(exc.detail, str)
                    else "An unexpected error occurred.",
                    "error_detail": f"Error code: {exc.status_code}",
                },
                status_code=exc.status_code,
            )

        # Delegate to the global custom handler for consistent JSON error responses
        return await global_http_exception_handler(request, exc)


def register_internal_routes(app: FastAPI) -> None:
    """Register root info and health routes (all under the API prefix)."""
    settings = get_settings()

    @app.get(f"{settings.API_V1_STR}/")
    async def api_root():
        return {
            "message": "Sonde API is running",
            "status": "healthy",
            "version": settings.VERSION,
            "docs": f"{settings.API_V1_STR}/docs",
            "health": f"{settings.API_V1_STR}/health",
        }

    @app.get(f"{settings.API_V1_STR}/health")
    async def health_check():
        return {"status": "healthy"}

    @app.get(f"{settings.API_V1_STR}/health/ready")
    async def readiness_check():
        try:
            redis_status = await get_shared_redis().check_health()
            db_status = await check_db_readiness()
            overall_status = (
                "healthy"
                if db_status["status"] == "healthy"
                and redis_status["status"] == "healthy"
                else "unhealthy"
            )
            payload = {
                "status": overall_status,
                "db": db_status,
                "redis": redis_status,
            }
            status_code = 200 if overall_status == "healthy" else 503
            return JSONResponse(status_code=status_code, content=payload)
        except Exception as exc:
            logger.error("Readiness check failed: %s", exc)
            return JSONResponse(
                status_code=503,
                content={"status": "unhealthy", "error": str(exc)},
            )
