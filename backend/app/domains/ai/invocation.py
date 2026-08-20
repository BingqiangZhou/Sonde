"""AI model invocation: HTTP call, retry, and error classification.

The single entrypoint for OpenAI-compatible chat/completions calls. Raw
aiohttp (not the openai SDK) keeps any compatible endpoint configurable via
base URLs. Errors raise domain exceptions — never FastAPI types — because
invocations also run inside Celery workers.
"""

import asyncio
import json
import logging
import time
from collections.abc import Callable, Coroutine
from typing import Any

import aiohttp

from app.core.config import settings
from app.core.http_client import get_shared_http_session
from app.core.utils import calculate_backoff


logger = logging.getLogger(__name__)


class RetryableAIModelError(Exception):
    """Transient AI model invocation error that can be retried."""


class AIClientError(Exception):
    """Error raised when an AI model invocation fails after all retries."""

    def __init__(self, message, model_name=None, provider=None, original_error=None):
        super().__init__(message)
        self.model_name = model_name
        self.provider = provider
        self.original_error = original_error


def is_retryable_http_status(status_code: int) -> bool:
    """Check if HTTP status code indicates a retryable error.

    Retryable status codes:
    - 5xx: Server errors
    - 408: Request Timeout
    - 409: Conflict
    - 425: Too Early
    - 429: Too Many Requests
    """
    return status_code >= 500 or status_code in {408, 409, 425, 429}


def looks_like_html_error_page(text: str) -> bool:
    """Check if response content looks like an HTML error page.

    This detects cases where a proxy (e.g., Cloudflare) returns
    an HTML error page instead of the expected JSON response.
    """
    lowered = text.lower()
    markers = (
        "<!doctype html",
        "<html",
        "<head",
        "cloudflare",
        "524: a timeout occurred",
        "/cdn-cgi/",
    )
    return any(marker in lowered for marker in markers)


def build_chat_url(base_url: str) -> str:
    """Ensure the URL ends with /chat/completions."""
    if base_url.endswith("/chat/completions"):
        return base_url
    return f"{base_url.rstrip('/')}/chat/completions"


async def _make_ai_http_request(
    session: aiohttp.ClientSession,
    *,
    url: str,
    headers: dict[str, str],
    payload: dict[str, Any],
    timeout: aiohttp.ClientTimeout,
    model_label: str = "unknown",
) -> str:
    """Shared HTTP request logic for AI API calls.

    Sends a POST request, validates the response, and returns the
    extracted content string from ``choices[0].message.content``.

    Raises:
        RetryableAIModelError: For retryable HTTP status codes.
        AIClientError: For non-retryable failures or invalid responses.
    """
    async with session.post(
        url, headers=headers, json=payload, timeout=timeout
    ) as response:
        response_text = await response.text()
        content_type = response.headers.get("Content-Type", "")

        # Detect HTML error pages
        if "text/html" in content_type.lower() or (
            looks_like_html_error_page(response_text)
            and "application/json" not in content_type.lower()
        ):
            raise AIClientError(
                "AI provider returned an HTML error page instead of JSON response",
            )

        # Handle non-200 status codes
        if response.status != 200:
            if is_retryable_http_status(response.status):
                raise RetryableAIModelError(
                    f"AI API transient error: {response.status} - {response_text[:200]}",
                )
            logger.error(
                "AI API error %d for model %s: %s",
                response.status,
                model_label,
                response_text[:200],
            )
            raise AIClientError("AI service error. Please try again later.")

        # Parse JSON response
        try:
            result = json.loads(response_text)
        except json.JSONDecodeError as exc:
            raise AIClientError(
                "AI provider returned non-JSON response",
            ) from exc

        # Validate response structure
        if "choices" not in result or not result["choices"]:
            raise AIClientError("Invalid response from AI API")

        content = result["choices"][0].get("message", {}).get("content")
        if not content or not isinstance(content, str):
            raise AIClientError("AI API returned empty or invalid content")

        return content


async def call_ai_api(
    model_config: Any,
    api_key: str,
    prompt: str,
    *,
    max_prompt_length: int | None = None,
) -> str:
    """Make a raw AI API call and return the response content.

    Args:
        model_config: Model configuration object with attributes:
            - api_url: Base API URL
            - model_id: Model identifier
            - timeout_seconds: Request timeout
            - max_tokens: Optional max tokens
            - extra_config: Optional extra configuration dict
            - temperature: Optional temperature parameter
        api_key: API key for authentication
        prompt: The prompt to send
        max_prompt_length: Maximum prompt length before truncation (defaults to settings.AI_CLIENT_MAX_PROMPT_LENGTH)

    Returns:
        The content string from the AI response

    Raises:
        AIClientError: For non-retryable errors
        RetryableAIModelError: For retryable errors
    """
    if max_prompt_length is None:
        max_prompt_length = settings.AI_CLIENT_MAX_PROMPT_LENGTH
    # Truncate prompt if too long
    if len(prompt) > max_prompt_length:
        prompt = prompt[:max_prompt_length] + "\n\n[Content too long, truncated]"

    url = build_chat_url(model_config.api_url)
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload: dict[str, Any] = {
        "model": model_config.model_id,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": model_config.temperature or 0.7,
    }
    if model_config.max_tokens is not None:
        payload["max_tokens"] = model_config.max_tokens
    if model_config.extra_config:
        payload.update(model_config.extra_config)

    session = await get_shared_http_session()
    content = await _make_ai_http_request(
        session,
        url=url,
        headers=headers,
        payload=payload,
        timeout=aiohttp.ClientTimeout(total=model_config.timeout_seconds),
        model_label=model_config.model_id,
    )

    # Check for HTML error in content
    if looks_like_html_error_page(content):
        raise AIClientError(
            "AI provider returned HTML error content inside the completion payload",
        )

    return content


async def call_ai_api_with_retry(
    model_config: Any,
    api_key: str,
    prompt: str,
    response_parser: Callable[[str], Coroutine[Any, Any, Any]],
    ai_model_repo: Any,
    *,
    operation_name: str = "AI API",
    max_retries: int | None = None,
    base_delay: int | None = None,
    max_prompt_length: int | None = None,
) -> tuple[Any, float, int]:
    """Call AI API with exponential backoff retry logic.

    Args:
        model_config: Model configuration object
        api_key: API key for authentication
        prompt: The prompt to send
        response_parser: Async callable to parse the response content
        ai_model_repo: Repository for tracking usage (must have increment_usage method)
        operation_name: Name for logging (e.g., "Summary generation")
        max_retries: Maximum retry attempts (defaults to settings.AI_CLIENT_MAX_RETRIES)
        base_delay: Base delay in seconds for exponential backoff (defaults to settings.AI_CLIENT_BASE_DELAY)
        max_prompt_length: Maximum prompt length before truncation (defaults to settings.AI_CLIENT_MAX_PROMPT_LENGTH)

    Returns:
        Tuple of (parsed_response, processing_time, tokens_used)

    Raises:
        AIClientError: If all retries fail or non-retryable error occurs
    """
    if max_retries is None:
        max_retries = settings.AI_CLIENT_MAX_RETRIES
    if base_delay is None:
        base_delay = settings.AI_CLIENT_BASE_DELAY
    if max_prompt_length is None:
        max_prompt_length = settings.AI_CLIENT_MAX_PROMPT_LENGTH
    for attempt in range(max_retries):
        attempt_start = time.time()
        try:
            # Make API call
            response_content = await call_ai_api(
                model_config=model_config,
                api_key=api_key,
                prompt=prompt,
                max_prompt_length=max_prompt_length,
            )

            # Parse response
            parsed_response = await response_parser(response_content)

            # Calculate metrics
            processing_time = time.time() - attempt_start
            tokens_used = len(prompt.split()) + len(str(response_content).split())

            # Track successful usage
            await ai_model_repo.increment_usage(
                model_config.id,
                success=True,
                tokens_used=tokens_used,
            )

            return parsed_response, processing_time, tokens_used

        except (
            RetryableAIModelError,
            TimeoutError,
            aiohttp.ClientError,
        ) as exc:
            # Track failed usage
            await ai_model_repo.increment_usage(model_config.id, success=False)

            if attempt < max_retries - 1:
                logger.warning(
                    "%s transient error model=%s provider=%s attempt=%s/%s retryable=true error_type=%s error=%s",
                    operation_name,
                    model_config.name,
                    model_config.provider,
                    attempt + 1,
                    max_retries,
                    type(exc).__name__,
                    exc,
                )
                await asyncio.sleep(calculate_backoff(attempt, base_delay))
                continue

            # Retries exhausted
            logger.error(
                "%s transient retries exhausted model=%s provider=%s attempts=%s error_type=%s error=%s",
                operation_name,
                model_config.name,
                model_config.provider,
                max_retries,
                type(exc).__name__,
                exc,
            )
            raise AIClientError(
                f"Model {model_config.name} failed after {max_retries} attempts: {exc}",
                model_name=model_config.name,
                provider=model_config.provider,
                original_error=exc,
            ) from exc

        except Exception as exc:
            # Track failed usage
            await ai_model_repo.increment_usage(model_config.id, success=False)

            logger.error(
                "%s non-retryable failure model=%s provider=%s retryable=false error_type=%s error=%s",
                operation_name,
                model_config.name,
                model_config.provider,
                type(exc).__name__,
                exc,
            )
            raise AIClientError(
                f"Model {model_config.name} failed without retry: {exc}",
                model_name=model_config.name,
                provider=model_config.provider,
                original_error=exc,
            ) from exc

    raise AIClientError("Unexpected error in call_ai_api_with_retry")
