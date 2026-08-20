"""Encrypted AI-key export/import round-trip tests (no plaintext export)."""

import json

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.services.apikeys_service import AdminApiKeysService
from app.core.security import encrypt_data
from app.domains.ai.models import AIModelConfig


@pytest_asyncio.fixture
async def seeded_service(db_session: AsyncSession) -> AdminApiKeysService:
    db_session.add(
        AIModelConfig(
            name="sf-whisper",
            display_name="SiliconFlow Whisper",
            provider="siliconflow",
            model_type="transcription",
            api_url="https://api.siliconflow.com/v1",
            api_key=encrypt_data("sk-live-secret-value"),
            api_key_encrypted=True,
            model_id="FunAudioLLM/SenseVoiceSmall",
            priority=1,
            is_active=True,
        )
    )
    await db_session.commit()
    return AdminApiKeysService(db_session)


@pytest.mark.asyncio
async def test_plaintext_export_is_rejected(seeded_service):
    payload, status = await seeded_service.export_json(
        request=None, user_id=1, mode="plaintext", export_password=None
    )

    assert status == 400
    assert not payload["success"]
    assert "disabled" in payload["message"]


@pytest.mark.asyncio
async def test_short_export_password_is_rejected(seeded_service):
    payload, status = await seeded_service.export_json(
        request=None, user_id=1, mode="encrypted", export_password="short"
    )

    assert status == 400
    assert not payload["success"]


@pytest.mark.asyncio
async def test_encrypted_export_contains_no_plaintext_key(seeded_service):
    content, _filename = await seeded_service.export_json(
        request=None, user_id=1, mode="encrypted", export_password="Correct-Horse-42"
    )

    data = json.loads(content)
    assert data["version"] == "2.1"
    assert data["export_mode"] == "encrypted"
    assert data["kdf"]["salt"]
    assert "sk-live-secret-value" not in content
    assert data["apikeys"][0]["api_key_encrypted"] is True


@pytest.mark.asyncio
async def test_import_roundtrip_with_password(seeded_service, db_session):
    content, _ = await seeded_service.export_json(
        request=None, user_id=1, mode="encrypted", export_password="Correct-Horse-42"
    )

    body = json.dumps(
        {
            "file": content,
            "mode": "update",
            "import_password": "Correct-Horse-42",
        }
    ).encode()
    payload, status = await seeded_service.import_json(
        request=None, user_id=1, raw_body=body
    )

    assert status == 200
    assert payload["stats"]["updated_count"] == 1
    assert payload["stats"]["error_count"] == 0


@pytest.mark.asyncio
async def test_import_with_wrong_password_fails_per_row(seeded_service):
    content, _ = await seeded_service.export_json(
        request=None, user_id=1, mode="encrypted", export_password="Correct-Horse-42"
    )

    body = json.dumps(
        {
            "file": content,
            "mode": "skip",
            "import_password": "wrong-password-1",
        }
    ).encode()
    payload, status = await seeded_service.import_json(
        request=None, user_id=1, raw_body=body
    )

    assert status == 200
    assert payload["stats"]["error_count"] == 1
    assert "password" in payload["stats"]["errors"][0] or "password" in " ".join(
        payload.get("errors", [])
    )


@pytest.mark.asyncio
async def test_encrypted_file_requires_password(seeded_service):
    content, _ = await seeded_service.export_json(
        request=None, user_id=1, mode="encrypted", export_password="Correct-Horse-42"
    )

    body = json.dumps({"file": content, "mode": "skip"}).encode()
    payload, status = await seeded_service.import_json(
        request=None, user_id=1, raw_body=body
    )

    assert status == 400
    assert not payload["success"]
