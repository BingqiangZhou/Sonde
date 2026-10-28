"""JWT/password 工具单测（Phase B）。"""

from __future__ import annotations

from datetime import timedelta

import pytest
from fastapi import HTTPException

from app.core.security import (
    create_access_token,
    create_refresh_token,
    get_password_hash,
    get_user_id_from_token,
    verify_password,
    verify_token,
)


async def test_access_token_roundtrip():
    token = await create_access_token({"sub": "42", "email": "a@b.c"})
    payload = await verify_token(token)
    assert payload["sub"] == "42"
    assert get_user_id_from_token(payload) == 42


async def test_expired_token_rejected():
    token = await create_access_token({"sub": "1"}, expires_delta=timedelta(seconds=-10))
    with pytest.raises(HTTPException) as e:
        await verify_token(token)
    assert e.value.status_code == 401


async def test_refresh_token_type_mismatch():
    refresh = await create_refresh_token({"sub": "1"})
    # access 校验拒绝 refresh 类型
    with pytest.raises(HTTPException) as e:
        await verify_token(refresh, token_type="access")
    assert e.value.status_code == 401
    # refresh 校验通过
    payload = await verify_token(refresh, token_type="refresh")
    assert payload["type"] == "refresh"


async def test_garbage_token_rejected():
    with pytest.raises(HTTPException):
        await verify_token("not.a.jwt")


def test_password_hash_verify():
    h = get_password_hash("s3cret-password")
    assert h != "s3cret-password"
    assert verify_password("s3cret-password", h)
    assert not verify_password("wrong", h)
    assert not verify_password("x", "not-a-hash")  # 畸形哈希不抛异常
