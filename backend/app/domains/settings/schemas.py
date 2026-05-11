from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# ---- Provider Schemas ----
class ProviderCreate(BaseModel):
    name: str
    provider_type: str = Field(description="openai, deepseek, openrouter, custom")
    base_url: str
    api_key: str = Field(description="Plain text API key — will be encrypted on save")
    is_active: bool = True


class ProviderUpdate(BaseModel):
    name: str | None = None
    provider_type: str | None = None
    base_url: str | None = None
    api_key: str | None = None
    is_active: bool | None = None


class ProviderResponse(BaseModel):
    id: UUID
    name: str
    provider_type: str
    base_url: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    models: list[ModelResponse] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class ProviderListResponse(BaseModel):
    items: list[ProviderResponse]
    total: int


# ---- Model Schemas ----
class ModelCreate(BaseModel):
    provider_id: UUID
    model_name: str
    temperature: float = 0.3
    max_tokens: int = 4096
    is_default: bool = False


class ModelUpdate(BaseModel):
    model_name: str | None = None
    temperature: float | None = None
    max_tokens: int | None = None
    is_default: bool | None = None


class ModelResponse(BaseModel):
    id: UUID
    provider_id: UUID
    model_name: str
    temperature: float
    max_tokens: int
    is_default: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ModelListResponse(BaseModel):
    items: list[ModelResponse]
    total: int


# ---- Test Connection ----
class TestConnectionResponse(BaseModel):
    success: bool
    message: str
    model: str | None = None


# ---- Prompt Template Schemas ----
class PromptTemplateCreate(BaseModel):
    name: str
    content: str


class PromptTemplateResponse(BaseModel):
    id: UUID
    name: str
    content: str
    version: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PromptTemplateListResponse(BaseModel):
    items: list[PromptTemplateResponse]
    total: int


ProviderResponse.model_rebuild()
