from datetime import UTC, datetime

from app.domains.podcast.routes.response_assemblers import (
    build_conversation_history_response,
    build_conversation_session_list_response,
    build_daily_report_dates_response,
    build_episode_list_response,
    build_feed_response,
    build_summary_models_response,
    build_summary_response,
)
from app.domains.podcast.schemas import (
    PodcastConversationClearResponse,
    PodcastSummaryPendingResponse,
    ScheduleConfigResponse,
)


def _episode_payload(now: datetime) -> dict:
    return {
        "id": 1,
        "subscription_id": 2,
        "title": "Episode 1",
        "description": "desc",
        "audio_url": "https://example.com/audio.mp3",
        "audio_duration": 1200,
        "published_at": now,
        "image_url": "https://example.com/ep.jpg",
        "subscription_image_url": "https://example.com/sub.jpg",
        "ai_summary": "summary",
        "summary_version": "v1",
        "ai_confidence_score": 0.9,
        "season": None,
        "episode_number": None,
        "explicit": False,
        "status": "published",
        "metadata": {},
        "subscription_title": "Podcast",
        "created_at": now,
        "updated_at": now,
    }


def test_build_feed_response_wraps_episode_items():
    now = datetime.now(UTC)

    response = build_feed_response(
        [_episode_payload(now)],
        has_more=True,
        next_page=None,
        next_cursor="cursor-1",
        total=7,
    )

    assert response.total == 7
    assert response.has_more is True
    assert response.next_cursor == "cursor-1"
    assert response.items[0].title == "Episode 1"


def test_build_episode_list_response_sets_pagination():
    now = datetime.now(UTC)

    response = build_episode_list_response(
        [_episode_payload(now)],
        total=21,
        page=2,
        size=10,
        subscription_id=5,
        next_cursor="cursor-2",
    )

    assert response.page == 2
    assert response.size == 10
    assert response.pages == 3
    assert response.subscription_id == 5
    assert response.next_cursor == "cursor-2"


def test_build_conversation_responses_wrap_payloads():
    now = datetime.now(UTC)

    session_list = build_conversation_session_list_response(
        [
            {
                "id": 3,
                "episode_id": 9,
                "title": "Session A",
                "message_count": 2,
                "created_at": now,
                "updated_at": now,
            },
        ],
    )
    history = build_conversation_history_response(
        episode_id=9,
        session_id=3,
        messages=[
            {
                "id": 1,
                "role": "user",
                "content": "Hello",
                "conversation_turn": 0,
                "created_at": now.isoformat(),
            },
        ],
    )
    clear = PodcastConversationClearResponse(
        episode_id=9,
        session_id=3,
        deleted_count=4,
    )

    assert session_list.total == 1
    assert session_list.items[0].message_count == 2
    assert history.total == 1
    assert history.messages[0].content == "Hello"
    assert clear.deleted_count == 4


def test_build_report_dates_response():
    now = datetime.now(UTC)

    report_dates = build_daily_report_dates_response(
        {
            "dates": [
                {
                    "report_date": now.date(),
                    "total_items": 1,
                    "generated_at": now,
                },
            ],
            "total": 1,
            "page": 1,
            "size": 30,
            "pages": 1,
        },
    )

    assert report_dates.items[0].total_items == 1


def test_build_summary_response_basic():
    now = datetime.now(UTC)

    summary = build_summary_response(
        episode_id=9,
        summary_result={
            "summary": "alpha beta gamma",
            "version": "v2",
            "generated_at": now,
            "model_name": "gpt-test",
            "processing_time": 1.2,
        },
    )

    assert summary.word_count == 3


def test_build_summary_response_accepts_model_used_key():
    now = datetime.now(UTC)

    summary = build_summary_response(
        episode_id=9,
        summary_result={
            "summary": "alpha beta gamma",
            "version": "v2",
            "generated_at": now,
            "model_used": "workflow-model",
            "processing_time": 1.2,
        },
    )

    assert summary.model_used == "workflow-model"
    assert summary.word_count == 3


def test_build_pending_and_model_responses():
    pending_episodes = [
        {"id": 1, "title": "Episode 1"},
        {"id": 2, "title": "Episode 2"},
    ]
    pending = PodcastSummaryPendingResponse(
        count=len(pending_episodes), episodes=pending_episodes
    )
    models = build_summary_models_response(
        [
            {
                "id": 1,
                "name": "default",
                "display_name": "Default",
                "provider": "openai",
                "model_id": "gpt-test",
                "is_default": True,
            },
        ],
    )

    assert pending.count == 2
    assert models.total == 1
    assert models.models[0].name == "default"


def test_build_schedule_config_list_response():
    now = datetime.now(UTC)
    schedule_dict = {
        "id": 5,
        "title": "Podcast 5",
        "update_frequency": "DAILY",
        "update_time": "08:30",
        "update_day_of_week": None,
        "fetch_interval": 3600,
        "next_update_at": now,
        "last_updated_at": now,
    }

    listing = [ScheduleConfigResponse(**schedule_dict)]

    assert listing[0].id == 5
    assert listing[0].update_time == "08:30"
    assert listing[0].title == "Podcast 5"
