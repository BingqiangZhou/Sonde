import os
from tempfile import TemporaryDirectory

import pytest

from app.domains.podcast.transcription import AudioChunk, SiliconFlowTranscriber


class _SuccessfulResponse:
    status = 200

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        return False

    async def json(self):
        return {"text": "hello world"}

    async def text(self):
        return ""


class _CapturingSession:
    """Capture the audio bytes posted in the multipart form."""

    def __init__(self):
        self.posted_file_bytes: bytes | None = None

    def post(self, url, data):
        del url
        payload = data()
        for part, *_ in getattr(payload, "_parts", []):
            value = getattr(part, "_value", None)
            if isinstance(value, (bytes, bytearray)):
                self.posted_file_bytes = bytes(value)
        return _SuccessfulResponse()


@pytest.mark.asyncio
async def test_transcribe_chunk_posts_buffered_file_bytes():
    with TemporaryDirectory() as temp_dir:
        chunk_path = os.path.join(temp_dir, "chunk.mp3")
        with open(chunk_path, "wb") as file_obj:
            file_obj.write(b"fake audio bytes")

        chunk = AudioChunk(
            index=1,
            file_path=chunk_path,
            start_time=0.0,
            duration=5.0,
            file_size=os.path.getsize(chunk_path),
        )
        session = _CapturingSession()
        transcriber = SiliconFlowTranscriber("test-key", "https://example.com")
        transcriber.session = session

        result = await transcriber.transcribe_chunk(chunk)

        assert result.transcript == "hello world"
        assert session.posted_file_bytes == b"fake audio bytes"
