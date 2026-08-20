"""Refresh-token revocation registry (redis-backed denylist).

Refresh tokens are single-use: every rotation revokes the presented token's
``jti`` and logout revokes it explicitly, so a replayed or stolen refresh
token stops working within one refresh cycle.

The registry fails open when Redis is unavailable: refresh availability wins
over revocation enforcement, and the exposure window is bounded by the
token's own expiry (14 days).
"""

import logging

from app.core.redis import RedisCache, get_shared_redis
from app.domains.auth.security import REFRESH_TOKEN_TTL


logger = logging.getLogger(__name__)

_KEY_PREFIX = "auth:revoked-refresh:"
_TTL_SECONDS = int(REFRESH_TOKEN_TTL.total_seconds())


class RefreshTokenRegistry:
    """Track revoked refresh-token jtis in Redis."""

    def __init__(self, redis: RedisCache | None = None):
        self._redis = redis

    def _client(self) -> RedisCache:
        return self._redis or get_shared_redis()

    async def revoke(self, jti: str) -> None:
        if not jti:
            return
        try:
            await self._client().set(f"{_KEY_PREFIX}{jti}", "1", ttl=_TTL_SECONDS)
        except Exception:
            logger.warning("Failed to revoke refresh token jti=%s", jti, exc_info=True)

    async def is_revoked(self, jti: str) -> bool:
        if not jti:
            return False
        try:
            return await self._client().exists(f"{_KEY_PREFIX}{jti}")
        except Exception:
            logger.warning(
                "Revocation check unavailable for jti=%s; failing open", jti
            )
            return False
