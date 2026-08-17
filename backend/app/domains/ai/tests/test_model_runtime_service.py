import os
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.domains.ai.services.text_generation_service import (
    AIModelRuntimeService,
    _is_retryable_http_status,
)


class _SuccessfulResponse:
    status = 200

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        return False

    async def json(self):
        return {"text": "transcribed text"}

    async def text(self):
        return ""


class _CapturingClientSession:
    """Capture the audio bytes posted in the multipart form."""

    def __init__(self):
        self.posted_file_bytes: bytes | None = None

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        return False

    def post(self, api_endpoint, headers=None, data=None, timeout=None):
        del api_endpoint, headers
        del timeout
        payload = data()
        for part, *_ in getattr(payload, "_parts", []):
            value = getattr(part, "_value", None)
            if isinstance(value, (bytes, bytearray)):
                self.posted_file_bytes = bytes(value)
        return _SuccessfulResponse()


@pytest.mark.asyncio
async def test_call_transcription_model_posts_buffered_file_bytes(monkeypatch):
    fake_session = _CapturingClientSession()
    monkeypatch.setattr(
        "app.domains.ai.services.text_generation_service.get_shared_http_session",
        AsyncMock(return_value=fake_session),
    )

    runtime_service = AIModelRuntimeService(
        repo=AsyncMock(),
        security_service=AsyncMock(
            get_decrypted_api_key=AsyncMock(return_value="sk-test")
        ),
    )
    model = SimpleNamespace(
        timeout_seconds=30,
        model_id="whisper-1",
        provider="openai",
        api_url="https://example.com",
        name="OpenAI Whisper",
    )

    with TemporaryDirectory() as temp_dir:
        audio_path = os.path.join(temp_dir, "audio.mp3")
        with open(audio_path, "wb") as file_obj:
            file_obj.write(b"fake audio bytes")

        result = await runtime_service._call_transcription_model(model, audio_path)

    assert result == "transcribed text"
    assert fake_session.posted_file_bytes == b"fake audio bytes"


def test_is_retryable_http_status():
    assert _is_retryable_http_status(500) is True
    assert _is_retryable_http_status(429) is True
    assert _is_retryable_http_status(408) is True
    assert _is_retryable_http_status(400) is False
    assert _is_retryable_http_status(401) is False
