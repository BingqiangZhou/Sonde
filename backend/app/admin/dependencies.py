"""Admin-related FastAPI dependency providers.

Uses lazy imports to avoid circular dependencies with admin services.
"""

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency


def get_admin_apikeys_service(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide request-scoped admin API-keys service."""
    from app.admin.services.apikeys_service import AdminApiKeysService

    return AdminApiKeysService(db)


__all__ = [
    "get_admin_apikeys_service",
]
