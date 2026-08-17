"""FastAPI application entrypoint."""

from fastapi import FastAPI

from app.bootstrap.http import (
    configure_exception_handlers,
    configure_middlewares,
    register_internal_routes,
)
from app.bootstrap.lifecycle import application_lifespan
from app.bootstrap.routers import include_application_routers
from app.core.config import get_settings
from app.core.json_encoder import CustomJSONResponse


def create_application() -> FastAPI:
    """Create and configure FastAPI application."""
    settings = get_settings()

    openapi_url = f"{settings.API_V1_STR}/openapi.json"
    docs_url = f"{settings.API_V1_STR}/docs"
    redoc_url = f"{settings.API_V1_STR}/redoc"
    oauth2_redirect_url = f"{settings.API_V1_STR}/docs/oauth2-redirect"
    if settings.ENVIRONMENT == "production":
        openapi_url = None
        docs_url = None
        redoc_url = None
        oauth2_redirect_url = None

    app = FastAPI(
        title=settings.PROJECT_NAME,
        description="Sonde API",
        version=settings.VERSION,
        openapi_url=openapi_url,
        docs_url=docs_url,
        redoc_url=redoc_url,
        swagger_ui_oauth2_redirect_url=oauth2_redirect_url,
        lifespan=application_lifespan,
        default_response_class=CustomJSONResponse,
    )

    configure_middlewares(app)
    configure_exception_handlers(app)
    include_application_routers(app)
    register_internal_routes(app)

    return app


app = create_application()
