"""Admin router aggregator."""

from fastapi import APIRouter

from app.admin.routes.apikeys import router as apikeys_router
from app.admin.routes.pair import router as pair_router
from app.admin.routes.setup_auth import router as setup_auth_router


router = APIRouter()
router.include_router(setup_auth_router)
router.include_router(pair_router)
router.include_router(apikeys_router)
