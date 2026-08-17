"""Admin-specific HTTP exception handling for route handlers.

The historical raise_* helper family was removed (zero call sites);
routes raise typed exceptions from app.core.exceptions directly.
"""

from fastapi import FastAPI, HTTPException, status
from fastapi.responses import RedirectResponse


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
