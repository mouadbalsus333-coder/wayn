import asyncio

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
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

        print("USER:", user.email)
        print("USER ID:", user.id)
        print("TOKEN VERSION:", user.token_version)


if __name__ == "__main__":
    asyncio.run(main())
