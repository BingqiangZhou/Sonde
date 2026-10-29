"""Shared episode mapping helpers for podcast services."""

from __future__ import annotations

from typing import Any

from app.core.utils import filter_thinking_content
from app.domains.podcast.models import PodcastEpisode


def _subscription_image_url(episode: PodcastEpisode) -> str | None:
    if episode.subscription and episode.subscription.config:
        value = episode.subscription.config.get("image_url")
        return value if isinstance(value, str) and value else None
    return None


def build_episode_dict(
    episode: PodcastEpisode,
    *,
    include_extended_fields: bool,
) -> dict[str, Any]:
    """Build one episode dict with optional extended fields."""
    subscription_image_url = _subscription_image_url(episode)
    image_url = episode.image_url or subscription_image_url
    cleaned_summary = filter_thinking_content(episode.ai_summary)

    payload: dict[str, Any] = {
        "id": episode.id,
        "subscription_id": episode.subscription_id,
        "subscription_title": episode.subscription.title
        if episode.subscription
        else None,
        "subscription_image_url": subscription_image_url,
        "title": episode.title,
        "description": episode.description,
        "audio_url": episode.audio_url,
        "audio_duration": episode.audio_duration,
        "published_at": episode.published_at,
        "image_url": image_url,
        "ai_summary": cleaned_summary,
        "status": episode.status,
        "created_at": episode.created_at,
        "updated_at": episode.updated_at,
    }

    if not include_extended_fields:
        return payload

    payload.update(
        {
            "audio_file_size": episode.audio_file_size,
            "item_link": episode.item_link,
            "transcript_url": episode.transcript_url,
            "transcript_content": episode.transcript.transcript_content
            if episode.transcript
            else None,
            "summary_version": episode.summary_version,
            "ai_confidence_score": episode.ai_confidence_score,
            "season": episode.season,
            "episode_number": episode.episode_number,
            "explicit": episode.explicit,
            "status": episode.status,
            "metadata": episode.metadata_json,
        },
    )
    return payload


def build_episode_dicts(
    episodes: list[PodcastEpisode],
    *,
    include_extended_fields: bool,
) -> list[dict[str, Any]]:
    """Build episode dicts for one page result."""
    return [
        build_episode_dict(
            episode=episode,
            include_extended_fields=include_extended_fields,
        )
        for episode in episodes
    ]
