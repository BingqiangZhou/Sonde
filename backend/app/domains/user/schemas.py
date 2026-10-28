"""User/auth API schemas（自 v0 历史恢复，收敛到本域内）。"""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, model_validator


class Token(BaseModel):
    """登录/注册/刷新成功返回。"""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class UserResponse(BaseModel):
    """用户信息（/auth/me）。"""

    id: int
    email: EmailStr
    username: str | None = None
    account_name: str | None = None
    is_active: bool
    is_superuser: bool
    is_verified: bool
    avatar_url: str | None = None
    created_at: datetime | None = None


class RegisterRequest(BaseModel):
    """注册请求；REGISTRATION_OPEN=false 时被拒。"""

    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    username: str | None = Field(None, max_length=100)
    remember_me: bool = False


class LoginRequest(BaseModel):
    """登录请求：email_or_username + password。"""

    username: str | None = Field(
        None, description="Username for login (alternative to email_or_username)"
    )
    email_or_username: EmailStr | str | None = Field(
        None, description="Email or username for login (alternative to username)"
    )
    password: str
    remember_me: bool = False

    @model_validator(mode="before")
    @classmethod
    def validate_identifier(cls, data):
        """Ensure either username or email_or_username is provided."""
        if (
            isinstance(data, dict)
            and not data.get("username")
            and not data.get("email_or_username")
        ):
            raise ValueError("Either username or email_or_username must be provided")
        return data


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str | None = None
