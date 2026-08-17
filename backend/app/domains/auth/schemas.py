"""Auth domain request/response schemas.

JSON field names match the Flutter ``auth_request.dart`` / ``auth_response.dart``
/ ``user.dart`` contracts exactly.
"""

from datetime import datetime

from pydantic import BaseModel, Field


# Mirrors the email regex validated client-side in the Flutter app.
EMAIL_PATTERN = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"


class RegisterRequest(BaseModel):
    """Registration payload — no name field; username is system-generated."""

    email: str = Field(..., pattern=EMAIL_PATTERN, max_length=255)
    password: str = Field(..., min_length=8, max_length=72)
    remember_me: bool = False


class LoginRequest(BaseModel):
    """Login by email or username."""

    email_or_username: str = Field(..., min_length=3, max_length=255)
    password: str = Field(..., min_length=1, max_length=72)
    remember_me: bool = False


class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., min_length=1)


class UpdateProfileRequest(BaseModel):
    """Rename payload — the user-editable identity is ``username``."""

    username: str = Field(..., min_length=2, max_length=30)


class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    expires_at: datetime
    server_time: datetime
    session_id: str


class UserResponse(BaseModel):
    id: int
    email: str
    username: str | None = None
    full_name: str | None = None
    avatar_url: str | None = None
    is_verified: bool = False
    is_active: bool = True
    is_superuser: bool = False
    created_at: datetime | None = None

    @classmethod
    def from_user(cls, user) -> "UserResponse":
        """Build the API view of a ``User`` ORM instance."""
        return cls(
            id=user.id,
            email=user.email,
            username=user.username,
            full_name=user.account_name,
            avatar_url=user.avatar_url,
            is_verified=bool(user.is_verified),
            is_active=user.is_active,
            is_superuser=bool(user.is_superuser),
            created_at=user.created_at,
        )
