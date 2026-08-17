# Exception Handling Guide

This document describes the exception handling architecture for the Sonde backend.

## Architecture Overview

The codebase uses a two-layer exception system:

1. **Service Layer** - Uses custom exception classes from `app.core.exceptions`
2. **Route Layer** - Uses convenience functions from `app.http.errors` that raise `HTTPException`

## When to Use What

### Service Layer (Business Logic)

Use custom exception classes from `app.core.exceptions`:

```python
from app.core.exceptions import (
    NotFoundError,
    CustomValidationError,
    ConflictError,
    UnauthorizedError,
    ForbiddenError,
)

# Example: Resource not found
if not user:
    raise NotFoundError(
        message="User not found",
        details={"user_id": user_id}
    )

# Example: Business validation failed
if balance < amount:
    raise CustomValidationError(
        message="Insufficient balance",
        details={"balance": balance, "required": amount}
    )

# Example: Duplicate resource
if existing_subscription:
    raise ConflictError(
        message="Subscription already exists",
        details={"feed_url": feed_url}
    )
```

### Route Layer (API Endpoints)

Use convenience functions from `app.http.errors` for bilingual responses:

```python
from app.http.errors import (
    raise_not_found,
    raise_validation_error,
    raise_unauthorized,
    raise_forbidden,
    bilingual_http_exception,
)

# Example: Entity not found with bilingual message
if not episode:
    raise_not_found(entity_type="Episode", entity_id=episode_id)
    # Returns: {"message_en": "Episode not found", "message_zh": "Episode未找到"}

# Example: Validation error with bilingual message
if not valid_url:
    raise_validation_error(field_name="url", reason="must be a valid RSS feed")
    # Returns: {"message_en": "Invalid url: must be a valid RSS feed", "message_zh": "url无效：must be a valid RSS feed"}

# Example: Custom bilingual error
raise bilingual_http_exception(
    message_en="Rate limit exceeded",
    message_zh="请求频率超限",
    status_code=429,
)
```

## Exception Classes Reference

### Custom Exception Classes (`app.core.exceptions`)

| Class | HTTP Status | Use Case |
|-------|-------------|----------|
| `BaseCustomError` | 500 | Base class for all custom exceptions |
| `NotFoundError` | 404 | Resource not found |
| `BadRequestError` | 400 | Malformed request |
| `UnauthorizedError` | 401 | Authentication required |
| `ForbiddenError` | 403 | Permission denied |
| `ConflictError` | 409 | Resource conflict (duplicate) |
| `CustomValidationError` | 400 | Business logic validation failure |
| `DatabaseError` | 500 | Database operation failure |
| `ExternalServiceError` | 502 | External API/service failure |
| `FileProcessingError` | 422 | File upload/processing failure |

### Convenience Functions (`app.http.errors`)

| Function | HTTP Status | Use Case |
|----------|-------------|----------|
| `raise_not_found()` | 404 | Entity not found (bilingual) |
| `raise_validation_error()` | 400 | Field validation failed (bilingual) |
| `raise_unauthorized()` | 401 | Authentication required (bilingual) |
| `raise_forbidden()` | 403 | Permission denied (bilingual) |
| `bilingual_http_exception()` | Any | Custom bilingual error |

## Migration Guide

### Before (using direct HTTPException)

```python
from fastapi import HTTPException

if not user:
    raise HTTPException(status_code=404, detail="User not found")
```

### After (using convenience functions)

```python
from app.http.errors import raise_not_found

if not user:
    raise_not_found(entity_type="User", entity_id=user_id)
```

## Best Practices

1. **Never import HTTPException from `app.core.exceptions`** - It doesn't exist there. Import from `fastapi` instead.

2. **Use bilingual errors for user-facing messages** - All API responses should use `app.http.errors` functions.

3. **Use custom exceptions for internal service errors** - Service layers should raise custom exceptions that will be caught by the global exception handler.

4. **Include details for debugging** - Pass `details` dict to custom exceptions for better error tracking.

5. **Don't catch and re-raise** - Let exceptions propagate to the global handler unless you need to add context.
