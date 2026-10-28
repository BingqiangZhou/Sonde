"""管理员建号 CLI（REGISTRATION_OPEN 关闭时的注册通道）。

用法（backend/ 下）：
    uv run python -m app.scripts.create_user <email> <password> [--username x] [--superuser]
"""

from __future__ import annotations

import argparse
import asyncio
import sys

from app.core.database import get_db_session
from app.domains.user.service import AuthenticationService


async def _create(email: str, password: str, username: str | None, superuser: bool) -> None:
    async for db in get_db_session():
        service = AuthenticationService(db)
        user = await service.admin_create_user(
            email=email, password=password, username=username, is_superuser=superuser
        )
        print(
            f"Created user id={user.id} email={user.email} "
            f"username={user.username} superuser={user.is_superuser}"
        )
        break


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a Sonde user")
    parser.add_argument("email")
    parser.add_argument("password")
    parser.add_argument("--username", default=None)
    parser.add_argument("--superuser", action="store_true")
    args = parser.parse_args()

    asyncio.run(_create(args.email, args.password, args.username, args.superuser))
    return 0


if __name__ == "__main__":
    sys.exit(main())
