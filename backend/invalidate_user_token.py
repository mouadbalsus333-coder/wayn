import asyncio

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.models.user import User


async def main():
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(User).where(
                User.email == "wayntest@gmail.com"
            )
        )

        user = result.scalar_one()

        print("OLD TOKEN VERSION:", user.token_version)

        user.token_version += 1

        await session.commit()

        print("NEW TOKEN VERSION:", user.token_version)


asyncio.run(main())
