import asyncio

from httpx import AsyncClient

from app.main import app


async def main() -> None:
    async with AsyncClient(app=app, base_url="http://test") as client:
        r1 = await client.get("/health")
        r2 = await client.get("/health/db")
        print("health", r1.status_code, r1.json())
        print("health/db", r2.status_code, r2.json())


if __name__ == "__main__":
    asyncio.run(main())