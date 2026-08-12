import asyncio
from sqlalchemy import text
from app.core.database import AsyncSessionLocal


async def main():
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            text("""
                SELECT
                    id,
                    name_ar,
                    name_en,
                    sort_order,
                    is_active
                FROM public.categories
            """)
        )

        rows = result.fetchall()

        print("ROWS =", len(rows))

        for row in rows:
            print("ID:", row[0])
            print("NAME_AR:", repr(row[1]))
            print("NAME_EN:", repr(row[2]))
            print("SORT:", row[3])
            print("ACTIVE:", row[4])


if __name__ == "__main__":
    asyncio.run(main())
