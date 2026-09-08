"""Store ads (rotating store banners) feature tests."""

import asyncio

import httpx
from sqlalchemy import delete, select

from app.core.database import AsyncSessionLocal, engine
from app.core.security import create_access_token
from app.main import app
from app.models.app_setting import AppSetting
from app.models.store_banner import StoreBanner
from tests.test_admin_security import (
    _create_admin_with_permissions,
    _delete_admin,
)


def _run(coroutine):
    async def run_and_dispose():
        try:
            return await coroutine
        finally:
            await engine.dispose()

    return asyncio.run(run_and_dispose())


async def _client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://testserver",
    )


async def _add_banners(rows: list[dict]) -> None:
    async with AsyncSessionLocal() as session:
        for row in rows:
            session.add(StoreBanner(**row))
        await session.commit()


async def _clear_banners() -> None:
    async with AsyncSessionLocal() as session:
        await session.execute(delete(StoreBanner))
        await session.commit()


async def _set_rotation(value: str) -> None:
    async with AsyncSessionLocal() as session:
        setting = (
            await session.execute(
                select(AppSetting).where(
                    AppSetting.key == "store_ads_rotation_seconds"
                )
            )
        ).scalar_one_or_none()
        if setting is None:
            session.add(AppSetting(key="store_ads_rotation_seconds", value=value))
        else:
            setting.value = value
        await session.commit()


BANNER_ROWS = [
    {
        "image_url": "https://cdn.example.com/a.webp",
        "target_url": "https://example.com/a",
        "sort_order": 2,
        "is_active": True,
    },
    {
        "image_url": "https://cdn.example.com/b.webp",
        "target_url": None,
        "sort_order": 1,
        "is_active": True,
    },
    {
        "image_url": "https://cdn.example.com/c.webp",
        "target_url": "https://example.com/c",
        "sort_order": 3,
        "is_active": False,
    },
]

# === PART 2: flow ===


async def _store_ads_flow() -> None:
    await _clear_banners()
    await _set_rotation("5")
    await _add_banners(BANNER_ROWS)

    try:
        async with await _client() as client:
            # Public API: active only, sorted by sort_order
            public = await client.get("/api/v1/store-ads")
            assert public.status_code == 200
            body = public.json()
            assert body["rotation_seconds"] == 5
            ads = body["ads"]
            assert len(ads) == 2
            assert [ad["sort_order"] for ad in ads] == [1, 2]
            assert all(ad["is_active"] for ad in ads)

            writer = await _create_admin_with_permissions(
                ["store.write", "store.delete"]
            )
            token = create_access_token(
                subject=str(writer.id),
                token_version=writer.token_version,
                token_type="admin",
            )
            headers = {"Authorization": f"Bearer {token}"}

            # Rotation seconds update + persistence
            update = await client.put(
                "/api/v1/admin/store-ads/settings",
                json={"rotation_seconds": 12},
                headers=headers,
            )
            assert update.status_code == 200
            assert update.json()["rotation_seconds"] == 12

            reloaded = await client.get("/api/v1/store-ads")
            assert reloaded.json()["rotation_seconds"] == 12

            # Out-of-range rotation is rejected
            bad_low = await client.put(
                "/api/v1/admin/store-ads/settings",
                json={"rotation_seconds": 0},
                headers=headers,
            )
            assert bad_low.status_code == 422

            bad_high = await client.put(
                "/api/v1/admin/store-ads/settings",
                json={"rotation_seconds": 61},
                headers=headers,
            )
            assert bad_high.status_code == 422

            # Admin CRUD: create, invalid URL rejected, update, delete
            create = await client.post(
                "/api/v1/admin/store/banners",
                json={
                    "image_url": "https://cdn.example.com/d.webp",
                    "target_url": "https://example.com/d",
                    "sort_order": 10,
                    "is_active": True,
                },
                headers=headers,
            )
            assert create.status_code == 201
            banner_id = create.json()["id"]

            invalid_url = await client.post(
                "/api/v1/admin/store/banners",
                json={
                    "image_url": "https://cdn.example.com/e.webp",
                    "target_url": "not-a-url",
                },
                headers=headers,
            )
            assert invalid_url.status_code == 422

            edited = await client.put(
                f"/api/v1/admin/store/banners/{banner_id}",
                json={"target_url": "https://example.com/changed"},
                headers=headers,
            )
            assert edited.status_code == 200
            assert edited.json()["target_url"] == "https://example.com/changed"

            deleted = await client.delete(
                f"/api/v1/admin/store/banners/{banner_id}",
                headers=headers,
            )
            assert deleted.status_code == 204

            # Permission split: admin without store.write gets 403
            reader = await _create_admin_with_permissions(["store.read"])
            reader_token = create_access_token(
                subject=str(reader.id),
                token_version=reader.token_version,
                token_type="admin",
            )
            reader_headers = {"Authorization": f"Bearer {reader_token}"}

            forbidden_create = await client.post(
                "/api/v1/admin/store/banners",
                json={"image_url": "https://cdn.example.com/f.webp"},
                headers=reader_headers,
            )
            assert forbidden_create.status_code == 403

            forbidden_settings = await client.put(
                "/api/v1/admin/store-ads/settings",
                json={"rotation_seconds": 8},
                headers=reader_headers,
            )
            assert forbidden_settings.status_code == 403

            settings_ok = await client.get(
                "/api/v1/admin/store-ads/settings",
                headers=reader_headers,
            )
            assert settings_ok.status_code == 200

            await _delete_admin(reader.id)
            await _delete_admin(writer.id)

            # Unauthenticated users cannot mutate anything
            anon_create = await client.post(
                "/api/v1/admin/store/banners",
                json={"image_url": "https://cdn.example.com/g.webp"},
            )
            assert anon_create.status_code == 401

            anon_settings = await client.put(
                "/api/v1/admin/store-ads/settings",
                json={"rotation_seconds": 8},
            )
            assert anon_settings.status_code == 401

            # Public API is read-only (no write routes under /store-ads)
            anon_post = await client.post(
                "/api/v1/store-ads",
                json={"image_url": "https://cdn.example.com/h.webp"},
            )
            assert anon_post.status_code == 405
    finally:
        await _clear_banners()


def test_store_ads_public_read_only_and_rotation():
    _run(_store_ads_flow())
