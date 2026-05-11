import logging
from uuid import UUID

import aiohttp
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decrypt_api_key, encrypt_api_key
from app.domains.settings.models import AIModelConfig, AIProviderConfig, PromptTemplate
from app.domains.settings.repository import (
    AIModelRepository,
    AIProviderRepository,
    PromptTemplateRepository,
    SettingsRepository,
)
from app.domains.settings.schemas import (
    ModelCreate,
    ModelResponse,
    PromptTemplateCreate,
    PromptTemplateListResponse,
    PromptTemplateResponse,
    ProviderCreate,
    ProviderResponse,
    ProviderUpdate,
    TestConnectionResponse,
)

logger = logging.getLogger(__name__)


class SettingsService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.provider_repo = AIProviderRepository(session)
        self.model_repo = AIModelRepository(session)
        self.settings_repo = SettingsRepository(session)
        self.prompt_repo = PromptTemplateRepository(session)

    # ---- Provider CRUD ----

    async def list_providers(self) -> list[ProviderResponse]:
        providers = await self.provider_repo.get_multi_with_models(limit=100)
        return [ProviderResponse.model_validate(p) for p in providers]

    async def get_provider(self, provider_id: UUID) -> ProviderResponse | None:
        provider = await self.provider_repo.get_with_models(provider_id)
        if provider is None:
            return None
        return ProviderResponse.model_validate(provider)

    async def create_provider(self, data: ProviderCreate) -> ProviderResponse:
        encrypted_key = encrypt_api_key(data.api_key)
        provider = await self.provider_repo.create({
            "name": data.name,
            "provider_type": data.provider_type,
            "base_url": data.base_url,
            "encrypted_api_key": encrypted_key,
            "is_active": data.is_active,
        })
        await self.session.flush()
        provider_with_models = await self.provider_repo.get_with_models(provider.id)
        return ProviderResponse.model_validate(provider_with_models or provider)

    async def update_provider(self, provider_id: UUID, data: ProviderUpdate) -> ProviderResponse | None:
        update_data = {}
        if data.name is not None:
            update_data["name"] = data.name
        if data.provider_type is not None:
            update_data["provider_type"] = data.provider_type
        if data.base_url is not None:
            update_data["base_url"] = data.base_url
        if data.api_key is not None:
            update_data["encrypted_api_key"] = encrypt_api_key(data.api_key)
        if data.is_active is not None:
            update_data["is_active"] = data.is_active

        if not update_data:
            provider = await self.provider_repo.get_with_models(provider_id)
            if provider is None:
                return None
            return ProviderResponse.model_validate(provider)

        provider = await self.provider_repo.update(provider_id, update_data)
        if provider is None:
            return None
        await self.session.flush()
        provider_with_models = await self.provider_repo.get_with_models(provider_id)
        return ProviderResponse.model_validate(provider_with_models or provider)

    async def delete_provider(self, provider_id: UUID) -> bool:
        # Also delete associated models (cascade will handle this)
        result = await self.provider_repo.delete(provider_id)
        if result:
            await self.session.flush()
        return result

    # ---- Model CRUD ----

    async def list_models(self, provider_id: UUID | None = None) -> list[ModelResponse]:
        if provider_id:
            models = await self.model_repo.get_by_provider(provider_id)
        else:
            models = await self.model_repo.get_multi(limit=100)
        return [ModelResponse.model_validate(m) for m in models]

    async def get_model(self, model_id: UUID) -> ModelResponse | None:
        model = await self.model_repo.get(model_id)
        if model is None:
            return None
        return ModelResponse.model_validate(model)

    async def create_model(self, data: ModelCreate) -> ModelResponse:
        # Verify provider exists
        provider = await self.provider_repo.get(data.provider_id)
        if provider is None:
            raise ValueError(f"Provider {data.provider_id} not found")

        # If this is set as default, unset other defaults for same provider
        if data.is_default:
            existing_models = await self.model_repo.get_by_provider(data.provider_id)
            for existing in existing_models:
                if existing.is_default:
                    await self.model_repo.update(existing.id, {"is_default": False})

        model = await self.model_repo.create({
            "provider_id": data.provider_id,
            "model_name": data.model_name,
            "temperature": data.temperature,
            "max_tokens": data.max_tokens,
            "is_default": data.is_default,
        })
        await self.session.flush()
        return ModelResponse.model_validate(model)

    async def update_model(self, model_id: UUID, data: dict) -> ModelResponse | None:
        model = await self.model_repo.get(model_id)
        if model is None:
            return None

        update_data = {}
        for field in ["model_name", "temperature", "max_tokens", "is_default"]:
            if field in data and data[field] is not None:
                update_data[field] = data[field]

        if update_data.get("is_default"):
            existing_models = await self.model_repo.get_by_provider(model.provider_id)
            for existing in existing_models:
                if existing.is_default and existing.id != model_id:
                    await self.model_repo.update(existing.id, {"is_default": False})

        if update_data:
            model = await self.model_repo.update(model_id, update_data)
            await self.session.flush()

        return ModelResponse.model_validate(model) if model else None

    async def delete_model(self, model_id: UUID) -> bool:
        result = await self.model_repo.delete(model_id)
        if result:
            await self.session.flush()
        return result

    # ---- Test Connection ----

    async def test_connection(self, provider_id: UUID) -> TestConnectionResponse:
        """Test the connection to an AI provider by listing models."""
        provider = await self.provider_repo.get(provider_id)
        if provider is None:
            return TestConnectionResponse(
                success=False,
                message="Provider not found",
            )

        try:
            api_key = decrypt_api_key(provider.encrypted_api_key)
        except Exception:
            return TestConnectionResponse(
                success=False,
                message="Failed to decrypt API key",
            )

        url = f"{provider.base_url.rstrip('/')}/models"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }

        try:
            async with aiohttp.ClientSession() as http_session:
                async with http_session.get(
                    url, headers=headers,
                    timeout=aiohttp.ClientTimeout(total=15),
                ) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        models = data.get("data", [])
                        model_names = [m.get("id", "") for m in models[:5]]
                        return TestConnectionResponse(
                            success=True,
                            message=f"Connected successfully. Found {len(models)} models.",
                            model=", ".join(model_names) if model_names else None,
                        )
                    else:
                        error_text = await resp.text()
                        return TestConnectionResponse(
                            success=False,
                            message=f"API returned status {resp.status}: {error_text[:200]}",
                        )
        except aiohttp.ClientError as e:
            return TestConnectionResponse(
                success=False,
                message=f"Connection error: {str(e)}",
            )
        except Exception as e:
            return TestConnectionResponse(
                success=False,
                message=f"Unexpected error: {str(e)}",
            )

    # ---- Prompt Template CRUD ----

    async def list_prompt_templates(self) -> PromptTemplateListResponse:
        templates = await self.prompt_repo.get_multi(limit=100)
        items = [PromptTemplateResponse.model_validate(t) for t in templates]
        return PromptTemplateListResponse(items=items, total=len(items))

    async def create_prompt_template(self, data: PromptTemplateCreate) -> PromptTemplateResponse:
        latest_version = await self.prompt_repo.get_latest_version()
        template = await self.prompt_repo.create({
            "name": data.name,
            "content": data.content,
            "version": latest_version + 1,
            "is_active": True,
        })
        # Deactivate all other templates
        all_templates = await self.prompt_repo.get_multi(limit=100)
        for t in all_templates:
            if t.id != template.id and t.is_active:
                await self.prompt_repo.update(t.id, {"is_active": False})
        await self.session.flush()
        return PromptTemplateResponse.model_validate(template)

    async def activate_prompt_template(self, template_id: UUID) -> PromptTemplateResponse | None:
        template = await self.prompt_repo.get(template_id)
        if template is None:
            return None
        # Deactivate all
        all_templates = await self.prompt_repo.get_multi(limit=100)
        for t in all_templates:
            if t.is_active:
                await self.prompt_repo.update(t.id, {"is_active": False})
        # Activate selected
        template = await self.prompt_repo.update(template_id, {"is_active": True})
        await self.session.flush()
        return PromptTemplateResponse.model_validate(template)

    async def get_active_prompt(self) -> PromptTemplateResponse | None:
        template = await self.prompt_repo.get_active()
        if template is None:
            return None
        return PromptTemplateResponse.model_validate(template)
