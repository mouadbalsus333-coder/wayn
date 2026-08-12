import asyncio
import asyncpg

from app.core.config import settings


async def check():
    database_url = settings.database_url.replace(
        "postgresql+asyncpg://",
        "postgresql://",
    )

    conn = await asyncpg.connect(database_url)

    count = await conn.fetchval(
        "SELECT COUNT(*) FROM places"
    )

    print("places count =", count)

    await conn.close()


asyncio.run(check())