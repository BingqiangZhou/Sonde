from datetime import UTC, datetime
from unittest.mock import AsyncMock, Mock, patch

import pytest

from app.domains.podcast.services import (
    PodcastEpisodeService,
    PodcastSubscriptionService,
)


def _build_mock_episode(
    *,
    description: str,
    ai_summary: str | None,
    created_at: datetime,
    published_at: datetime,
) -> Mock:
    episode = Mock()
    episode.id = 1
    episode.subscription_id = 1
    episode.subscription = None
    episode.title = "Episode title"
    episode.description = description
    episode.audio_url = "https://example.com/audio.mp3"
    episode.audio_duration = 120
    episode.audio_file_size = 1024
    episode.published_at = published_at
    episode.image_url = None
    episode.item_link = None
    episode.transcript_url = None
    episode.transcript = None
    episode.ai_summary = ai_summary
    episode.summary_version = "1.0"
    episode.ai_confidence_score = 0.9
    episode.play_count = 0
    episode.last_played_at = None
    episode.season = None
    episode.episode_number = None
    episode.explicit = False
    episode.status = "published"
    episode.metadata_json = {}
    episode.created_at = created_at
    episode.updated_at = created_at
    return episode


def _build_lightweight_feed_row(
    *,
    now: datetime,
    description: str,
    ai_summary: str | None,
    transcript_content: str | None,
) -> dict:
    return {
        "id": 1,
        "subscription_id": 1,
        "title": "Episode title",
        "description": description,
        "audio_url": "https://example.com/audio.mp3",
        "audio_duration": 1200,
        "published_at": now,
        "status": "published",
        "created_at": now,
        "updated_at": now,
        "ai_summary": ai_summary,
        "transcript_content": transcript_content,
    }


class TestPodcastSubscriptionService:
    """测试播客订阅服务"""

    @pytest.fixture
    def mock_db(self):
        return AsyncMock()

    @pytest.fixture
    def mock_repo(self):
        with patch(
            "app.domains.podcast.services.episode_service.PodcastRepository",
        ) as mock:
            repo_instance = AsyncMock()
            mock.return_value = repo_instance
            yield repo_instance

    @pytest.fixture
    def mock_parser(self):
        with patch(
            "app.domains.podcast.services.episode_service.SecureRSSParser",
        ) as mock:
            parser_instance = AsyncMock()
            mock.return_value = parser_instance
            yield parser_instance

    @pytest.fixture
    def service(self, mock_db, mock_repo, mock_parser):
        return PodcastSubscriptionService(mock_db, user_id=1)

    @pytest.mark.asyncio
    async def test_list_subscriptions_empty(self, service, mock_repo):
        """测试空订阅列表"""
        mock_repo.get_user_subscriptions_paginated.return_value = ([], 0, {})
        mock_repo.get_subscription_episodes_batch.return_value = {}
        mock_repo.get_playback_states_batch.return_value = {}

        results, total = await service.list_subscriptions()

        assert results == []
        assert total == 0
        mock_repo.get_user_subscriptions_paginated.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_subscription_details_not_found(self, service, mock_repo):
        """测试获取不存在的订阅详情"""
        mock_repo.get_subscription_by_id.return_value = None

        result = await service.get_subscription_details(999)

        assert result is None
        mock_repo.get_subscription_by_id.assert_called_once()


class TestPodcastEpisodeService:
    """测试播客单集服务"""

    @pytest.fixture
    def mock_db(self):
        return AsyncMock()

    @pytest.fixture
    def mock_repo(self):
        with patch(
            "app.domains.podcast.services.episode_service.PodcastRepository",
        ) as mock:
            repo_instance = AsyncMock()
            mock.return_value = repo_instance
            yield repo_instance

    @pytest.fixture
    def service(self, mock_db, mock_repo):
        return PodcastEpisodeService(mock_db, user_id=1)

    @pytest.mark.asyncio
    async def test_get_episode_by_id(self, service, mock_repo):
        """测试获取单集详情"""
        mock_episode = Mock()
        mock_episode.id = 1
        mock_repo.get_episode_by_id.return_value = mock_episode

        result = await service.get_episode_by_id(1)

        assert result == mock_episode
        mock_repo.get_episode_by_id.assert_called_once_with(1, 1)

    @pytest.mark.asyncio
    async def test_feed_prefers_one_line_summary(
        self,
        service,
        mock_repo,
    ):
        now = datetime.now(UTC)
        mock_repo.get_feed_lightweight_cursor_paginated.return_value = (
            [
                _build_lightweight_feed_row(
                    now=now,
                    description="fallback description",
                    ai_summary=(
                        "## Executive Summary\n"
                        "A concise summary sentence.\n\n"
                        "## Key Insights\n"
                        "More details."
                    ),
                    transcript_content="transcript",
                ),
            ],
            1,
            False,
            None,
        )

        results, total, has_more, _ = await service.list_feed(size=20)

        assert total == 1
        assert has_more is False
        assert results[0]["description"] == "A concise summary sentence."
        assert results[0]["ai_summary"] is None
        assert results[0]["transcript_content"] is None

    @pytest.mark.asyncio
    async def test_feed_falls_back_to_collapsed_description(
        self,
        service,
        mock_repo,
    ):
        now = datetime.now(UTC)
        raw_description = "   Fallback   text \n with   extra   spaces   "
        mock_repo.get_feed_lightweight_cursor_paginated.return_value = (
            [
                _build_lightweight_feed_row(
                    now=now,
                    description=raw_description,
                    ai_summary=None,
                    transcript_content="transcript",
                ),
            ],
            1,
            False,
            None,
        )

        results, total, has_more, next_cursor = await service.list_feed(
            size=20,
        )

        assert total == 1
        assert has_more is False
        assert next_cursor is None
        assert results[0]["description"] == "Fallback text with extra spaces"
        assert results[0]["ai_summary"] is None
        assert results[0]["transcript_content"] is None

    @pytest.mark.asyncio
    async def test_list_episodes_keeps_original_description(self, service, mock_repo):
        now = datetime.now(UTC)
        episode = _build_mock_episode(
            description="Original episode description",
            ai_summary=(
                "## Executive Summary\n"
                "Should not replace non-feed description.\n\n"
                "## Details\n"
                "More details."
            ),
            created_at=now,
            published_at=now,
        )
        mock_repo.get_episodes_paginated.return_value = ([episode], 1)
        mock_repo.get_playback_states_batch.return_value = {}

        results, total = await service.list_episodes(page=1, size=20)

        assert total == 1
        assert results[0]["description"] == "Original episode description"

    def test_resolve_feed_description_truncates_fallback(self, service):
        long_description = "a" * 500

        result = service._resolve_feed_description(
            ai_summary=None,
            fallback_description=long_description,
        )

        assert result is not None
        assert len(result) == service._feed_description_max_length
