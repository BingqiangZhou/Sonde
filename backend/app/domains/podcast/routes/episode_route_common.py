"""Shared helpers for podcast episode-related route modules."""

import base64
import binascii
import json
from datetime import UTC, datetime
from typing import Any

from fastapi import HTTPException, status


def encode_keyset_cursor(timestamp: datetime, episode_id: int) -> str:
    """Encode stable keyset cursor payload."""
    normalized = timestamp
    if normalized.tzinfo is not None:
        normalized = normalized.astimezone(UTC).replace(tzinfo=None)

    payload = {
        "v": 2,
        "ts": normalized.isoformat(),
        "id": episode_id,
    }
    raw = json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("utf-8").rstrip("=")


def decode_cursor(cursor: str) -> dict[str, Any]:
    """Decode a keyset cursor token used by the feed endpoint."""
    padding = "=" * (-len(cursor) % 4)
    try:
        decoded = base64.urlsafe_b64decode(f"{cursor}{padding}").decode("utf-8")
    except (ValueError, binascii.Error) as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid cursor",
        ) from exc

    try:
        payload = json.loads(decoded)
        if not isinstance(payload, dict):
            raise ValueError("payload must be object")

        timestamp_raw = payload.get("ts")
        episode_id = payload.get("id")
        if not isinstance(timestamp_raw, str):
            raise ValueError("timestamp missing")
        if not isinstance(episode_id, int) or episode_id <= 0:
            raise ValueError("episode id missing")

        timestamp = datetime.fromisoformat(timestamp_raw)
        if timestamp.tzinfo is not None:
            timestamp = timestamp.astimezone(UTC).replace(tzinfo=None)

        return {
            "ts": timestamp,
            "id": episode_id,
        }
    except (ValueError, TypeError, json.JSONDecodeError) as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid cursor",
        ) from exc
