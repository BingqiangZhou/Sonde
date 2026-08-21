"""Shared active-model resolution tests."""

from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.core.exceptions import ValidationError
from app.domains.ai.model_resolution import resolve_active_model_config
from app.domains.ai.models import ModelType


def _model(*, active=True, type_=ModelType.TRANSCRIPTION):
    return SimpleNamespace(is_active=active, model_type=type_)


@pytest.mark.asyncio
async def test_named_model_resolved_without_priority_query():
    repo = AsyncMock()
    repo.get_by_name.return_value = _model()
    model = await resolve_active_model_config(
        repo,
        model_type=ModelType.TRANSCRIPTION,
        model_name="sensevoice",
        operation_name="Transcription",
    )
    assert model is repo.get_by_name.return_value
    repo.get_active_models_by_priority.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "missing,inactive,wrong_type",
    [(True, False, False), (False, True, False), (False, False, True)],
)
async def test_named_model_rejections(missing, inactive, wrong_type):
    repo = AsyncMock()
    repo.get_by_name.return_value = (
        None
        if missing
        else _model(
            active=not inactive,
            type_=ModelType.TEXT_GENERATION if wrong_type else ModelType.TRANSCRIPTION,
        )
    )
    with pytest.raises(
        ValidationError, match="Transcription model 'x' not found or not active"
    ):
        await resolve_active_model_config(
            repo,
            model_type=ModelType.TRANSCRIPTION,
            model_name="x",
            operation_name="Transcription",
        )


@pytest.mark.asyncio
async def test_unnamed_falls_back_to_highest_priority_model():
    repo = AsyncMock()
    top = _model()
    repo.get_active_models_by_priority.return_value = [top, _model()]
    model = await resolve_active_model_config(
        repo,
        model_type=ModelType.TRANSCRIPTION,
        operation_name="Transcription",
    )
    assert model is top


@pytest.mark.asyncio
async def test_no_active_models_raises():
    repo = AsyncMock()
    repo.get_active_models_by_priority.return_value = []
    with pytest.raises(ValidationError, match="No active transcription model found"):
        await resolve_active_model_config(
            repo,
            model_type=ModelType.TRANSCRIPTION,
            operation_name="Transcription",
        )
