import asyncio

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.core.security import hash_password
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

        user.password_hash = hash_password("WaynTest2026!")

        await session.commit()

        print("TEST PASSWORD RESET: OK")
        print("EMAIL:", user.email)
        print("TOKEN VERSION:", user.token_version)


if __name__ == "__main__":
    asyncio.run(main())
