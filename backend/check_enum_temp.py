import asyncio

import asyncpg

from app.core.config import settings


async def check():
    database_url = settings.database_url.replace(
        "postgresql+asyncpg://",
        "postgresql://",
        1,
    )

    conn = await asyncpg.connect(database_url)

    postgis = await conn.fetchval("""
        SELECT extversion
        FROM pg_extension
        WHERE extname = 'postgis'
    """)

    print("PostGIS version =", postgis)

    await conn.close()


asyncio.run(check())