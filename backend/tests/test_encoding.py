"""Encoding and internationalization tests for Arabic (RTL) data.

Tests that the API correctly handles Arabic text in:
- Categories (name_ar)
- Places (name, city, category_name, description, address)
- Search queries
- JSON encoding
"""
import pytest
from httpx import AsyncClient
from sqlalchemy import text

from app.core.database import AsyncSessionLocal
from app.main import app


# ------------------------------------------------------------------
# Category Arabic data
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_existing_category_arabic(client):
    """The مطاعم category should return proper Arabic text."""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            text("SELECT id FROM categories WHERE name_ar = 'مطاعم' LIMIT 1")
        )
        cat_id = result.scalar_one()

    resp = await client.get(f"/api/v1/categories/{cat_id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["name_ar"] == "مطاعم"
    assert data["name_en"] == "Restaurants"


@pytest.mark.anyio
async def test_list_categories_arabic(client):
    resp = await client.get("/api/v1/categories")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 1
    # Find the مطاعم category
    found = any(c["name_ar"] == "مطاعم" for c in data)
    assert found


# ------------------------------------------------------------------
# Place Arabic data
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_create_place_with_arabic_data(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    async with AsyncClient(app=app, base_url="http://test") as c:
        resp = await c.post(
            "/api/v1/admin/places",
            json={
                "category_id": cat_id,
                "name": "مطعم الاختبار العربي",
                "city": "طرابلس",
                "category_name": "مطاعم",
                "image_url": "https://example.com/test.jpg",
                "rating": 4.5,
                "is_open": True,
                "is_active": True,
                "description": "وصف باللغة العربية",
                "address": "شارع النهضة، طرابلس",
                "phone": "+218 21 123 4567",
                "website": "https://example.com",
                "latitude": 32.8872,
                "longitude": 13.1913,
                "images": ["https://example.com/test.jpg"],
                "services": ["وي فاي", "موقف سيارات"],
                "opening_time": "08:00",
                "closing_time": "23:00",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "مطعم الاختبار العربي"
        assert data["city"] == "طرابلس"
        assert data["category_name"] == "مطاعم"
        assert data["description"] == "وصف باللغة العربية"
        assert data["address"] == "شارع النهضة، طرابلس"
        place_id = data["id"]

        # GET and verify Arabic is preserved
        resp = await c.get(f"/api/v1/places/{place_id}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == "مطعم الاختبار العربي"
        assert data["description"] == "وصف باللغة العربية"

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


@pytest.mark.anyio
async def test_search_arabic_query(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    async with AsyncClient(app=app, base_url="http://test") as c:
        resp = await c.post(
            "/api/v1/admin/places",
            json={
                "category_id": cat_id,
                "name": "مطعم بحث عربي",
                "city": "طرابلس",
                "category_name": "مطاعم",
                "image_url": "https://example.com/test.jpg",
                "rating": 4.0,
                "is_open": True,
                "is_active": True,
                "latitude": 32.8872,
                "longitude": 13.1913,
                "images": [],
                "services": [],
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 201
        place_id = resp.json()["id"]

        # Search with Arabic fragment
        resp = await c.get("/api/v1/places/search?q=بحث")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, dict)
        assert "items" in data
        assert len(data["items"]) >= 1
        assert any(p["name"] == "مطعم بحث عربي" for p in data["items"])

        # Search with partial Arabic match on city
        resp = await c.get("/api/v1/places/search?q=طرابلس")
        assert resp.status_code == 200
        data = resp.json()
        assert any(p["city"] == "طرابلس" for p in data["items"])

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


# ------------------------------------------------------------------
# JSON encoding
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_arabic_json_encoding(client):
    """Arabic characters must be properly encoded in JSON responses."""
    resp = await client.get("/api/v1/categories")
    assert resp.status_code == 200

    raw = resp.content.decode("utf-8")
    assert "مطاعم" in raw
    assert "Restaurants" in raw


@pytest.mark.anyio
async def test_arabic_in_response_model(client, admin_token, existing_category_id):
    """Verify Pydantic serializes Arabic correctly without mangling."""
    cat_id = existing_category_id
    async with AsyncClient(app=app, base_url="http://test") as c:
        resp = await c.post(
            "/api/v1/admin/places",
            json={
                "category_id": cat_id,
                "name": "مطعم ترميز",
                "city": "طرابلس",
                "category_name": "مطاعم",
                "image_url": "https://example.com/test.jpg",
                "rating": 4.0,
                "is_open": True,
                "is_active": True,
                "latitude": 32.8872,
                "longitude": 13.1913,
                "images": [],
                "services": [],
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 201
        place_id = resp.json()["id"]

        # Verify JSON is valid and contains correct Arabic
        resp = await c.get(f"/api/v1/places/{place_id}")
        assert resp.headers["content-type"].startswith("application/json")
        data = resp.json()
        assert data["name"] == "مطعم ترميز"

    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


# ------------------------------------------------------------------
# Empty query handling
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_search_empty_returns_all(client):
    """Empty search query should return all active places.

    The repository delegates to list_places when query is empty.
    """
    resp = await client.get("/api/v1/places/search?q=")
    assert resp.status_code == 200
    # Should match the list_places result
    resp_list = await client.get("/api/v1/places")
    assert resp_list.status_code == 200
    assert resp.json() == resp_list.json()
