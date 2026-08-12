import asyncio

from sqlalchemy import text

from app.core.database import AsyncSessionLocal


async def main():
    async with AsyncSessionLocal() as session:

        print("=" * 70)
        print("DATABASE CHECK")
        print("=" * 70)

        result = await session.execute(
            text("SELECT current_database(), current_schema()")
        )

        row = result.one()

        print("database =", row[0])
        print("schema   =", row[1])

        print()
        print("=" * 70)
        print("TABLE CHECK")
        print("=" * 70)

        result = await session.execute(
            text("""
                SELECT
                    table_schema,
                    table_name
                FROM information_schema.tables
                WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
                ORDER BY table_schema, table_name
            """)
        )

        tables = result.fetchall()

        for table in tables:
            print(f"{table[0]}.{table[1]}")

        print()
        print("=" * 70)
        print("CATEGORY COUNT")
        print("=" * 70)

        result = await session.execute(
            text("SELECT COUNT(*) FROM categories")
        )

        count = result.scalar_one()

        print("categories count =", count)

        print()
        print("=" * 70)
        print("CATEGORY DATA")
        print("=" * 70)

        result = await session.execute(
            text("""
                SELECT
                    id,
                    name_ar,
                    name_en,
                    sort_order,
                    is_active
                FROM categories
                ORDER BY sort_order, name_en
            """)
        )

        rows = result.mappings().all()

        if not rows:
            print("NO CATEGORY ROWS FOUND")
        else:
            for category in rows:
                print("id         =", category["id"])
                print("name_ar    =", repr(category["name_ar"]))
                print("name_en    =", repr(category["name_en"]))
                print("sort_order =", category["sort_order"])
                print("is_active  =", category["is_active"])
                print("-" * 70)


if __name__ == "__main__":
    asyncio.run(main())
