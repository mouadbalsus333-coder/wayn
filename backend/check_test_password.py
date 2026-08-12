import asyncio

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.core.security import verify_password
from app.models.user import User


async def main():
    async with AsyncSessionLocal() as session:
        user = await session.scalar(
            select(User).where(
                User.email == "wayntest@gmail.com"
            )
        )

        if user is None:
            print("USER NOT FOUND")
            return

        print("TOKEN VERSION:", user.token_version)

        print(
            "OLD PASSWORD VALID:",
            verify_password(
                "WaynTest2026!",
                user.password_hash,
            ),
        )

        print(
            "NEW PASSWORD VALID:",
            verify_password(
                "WaynTest2026@New",
                user.password_hash,
            ),
        )


if __name__ == "__main__":
    asyncio.run(main())
