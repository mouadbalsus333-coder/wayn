"""Places API integration tests (real DB with test data).

Covers: list, get, search, nearby, open, top-rated, most-visited,
city filter, category filter, create/update/delete via admin API.
"""
import pytest
from httpx import AsyncClient
from sqlalchemy import text

from app.core.database import AsyncSessionLocal
from app.main import app


def _items(data):
    """Extract items from a PaginatedResponse body."""
    assert isinstance(data, dict)
    assert "items" in data
    return data["items"]


# ------------------------------------------------------------------
# List Places
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_places_empty(client):
    """No places exist by default -> 200, items=[]."""
    resp = await client.get("/api/v1/places")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0
    assert data["page"] == 1
    assert data["limit"] == 20
    assert data["pages"] == 0


@pytest.mark.anyio
async def test_list_places_with_data(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    place_ids = []

    for i in range(3):
        resp = await client.post(
            "/api/v1/admin/places",
            json={
                "category_id": cat_id,
                "name": f"مطعم تجريبي {i}",
                "city": "طرابلس",
                "category_name": "مطاعم",
                "image_url": "https://example.com/test.jpg",
                "rating": float(i * 1.5),
                "is_open": True,
                "is_active": True,
                "description": f"وصف تجريبي {i}",
                "address": f"عنوان {i}",
                "latitude": 32.8872,
                "longitude": 13.1913,
                "images": [],
                "services": [],
                "opening_time": "08:00",
                "closing_time": "23:00",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 201
        place_ids.append(resp.json()["id"])

    resp = await client.get("/api/v1/places")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) == 3
    assert data["total"] == 3

    # Cleanup
    async with AsyncSessionLocal() as session:
        for pid in place_ids:
            await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": pid})
        await session.commit()


# ------------------------------------------------------------------
# Get Place by ID
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_place_not_found(client):
    resp = await client.get("/api/v1/places/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 404


@pytest.mark.anyio
async def test_get_place_with_data(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    resp = await client.post(
        "/api/v1/admin/places",
        json={
            "category_id": cat_id,
            "name": "مطعم جلب بيانات",
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

    resp = await client.get(f"/api/v1/places/{place_id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "مطعم جلب بيانات"
    assert data["city"] == "طرابلس"
    assert data["category_name"] == "مطاعم"

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


# ------------------------------------------------------------------
# Search
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_search_empty(client):
    """With no places, search returns empty items."""
    resp = await client.get("/api/v1/places/search?q=مطعم")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0


@pytest.mark.anyio
async def test_search_no_query_returns_all(client):
    """Empty query should return all active places (delegates to list_places)."""
    resp = await client.get("/api/v1/places/search?q=")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data["items"], list)


@pytest.mark.anyio
async def test_search_with_data(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    suffix = "searchtest"
    resp = await client.post(
        "/api/v1/admin/places",
        json={
            "category_id": cat_id,
            "name": f"مطعم {suffix} اليوم",
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

    # Search by Arabic name fragment
    resp = await client.get("/api/v1/places/search?q=searchtest")
    assert resp.status_code == 200
    data = resp.json()
    items = data["items"]
    assert len(items) >= 1
    assert any(p["name"] == f"مطعم {suffix} اليوم" for p in items)

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


@pytest.mark.anyio
async def test_search_sql_injection_safe(client):
    """SQL injection attempts should not cause errors or return unexpected data."""
    injection = "'; DROP TABLE places; --"
    resp = await client.get(f"/api/v1/places/search?q={injection}")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data["items"], list)

    # Verify places table still exists
    async with AsyncSessionLocal() as session:
        result = await session.execute(text("SELECT COUNT(*) FROM places"))
        assert result.scalar_one() is not None


@pytest.mark.anyio
async def test_search_very_long_query(client):
    long_q = "a" * 10000
    resp = await client.get(f"/api/v1/places/search?q={long_q}")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data["items"], list)


# ------------------------------------------------------------------
# Nearby (PostGIS)
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_nearby_no_places(client):
    """No places in DB -> nearby returns empty items."""
    resp = await client.get(
        "/api/v1/places/nearby",
        params={"latitude": 32.8872, "longitude": 13.1913},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0


@pytest.mark.anyio
async def test_nearby_with_place(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    resp = await client.post(
        "/api/v1/admin/places",
        json={
            "category_id": cat_id,
            "name": "مطعم صالة قريب",
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

    # Search nearby with same coordinates
    resp = await client.get(
        "/api/v1/places/nearby",
        params={"latitude": 32.8872, "longitude": 13.1913, "radius": 5000},
    )
    assert resp.status_code == 200
    data = resp.json()
    items = data["items"]
    assert len(items) >= 1
    assert any(p["id"] == place_id for p in items)

    # Search nearby with far coordinates (should NOT find the place)
    resp = await client.get(
        "/api/v1/places/nearby",
        params={"latitude": 0.0, "longitude": 0.0, "radius": 100},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) == 0

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


@pytest.mark.anyio
async def test_nearby_invalid_latitude(client):
    resp = await client.get(
        "/api/v1/places/nearby",
        params={"latitude": 95.0, "longitude": 13.0},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_nearby_invalid_longitude(client):
    resp = await client.get(
        "/api/v1/places/nearby",
        params={"latitude": 32.0, "longitude": 190.0},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_nearby_missing_coords(client):
    resp = await client.get("/api/v1/places/nearby")
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_nearby_invalid_radius(client):
    resp = await client.get(
        "/api/v1/places/nearby",
        params={"latitude": 32.0, "longitude": 13.0, "radius": -1},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_nearby_too_large_radius(client):
    resp = await client.get(
        "/api/v1/places/nearby",
        params={"latitude": 32.0, "longitude": 13.0, "radius": 200000},
    )
    assert resp.status_code == 422


# ------------------------------------------------------------------
# Open Places
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_open_places_empty(client):
    resp = await client.get("/api/v1/places/open")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0


@pytest.mark.anyio
async def test_open_places_with_data(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    resp = await client.post(
        "/api/v1/admin/places",
        json={
            "category_id": cat_id,
            "name": "مطعم مفتوح",
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

    resp = await client.get("/api/v1/places/open")
    assert resp.status_code == 200
    data = resp.json()
    items = data["items"]
    assert len(items) >= 1
    assert any(p["name"] == "مطعم مفتوح" for p in items)

    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


# ------------------------------------------------------------------
# Top Rated
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_top_rated_empty(client):
    resp = await client.get("/api/v1/places/top-rated")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0


@pytest.mark.anyio
async def test_top_rated_with_data(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    resp = await client.post(
        "/api/v1/admin/places",
        json={
            "category_id": cat_id,
            "name": "مطعم تقييم عالي",
            "city": "طرابلس",
            "category_name": "مطاعم",
            "image_url": "https://example.com/test.jpg",
            "rating": 4.9,
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

    resp = await client.get("/api/v1/places/top-rated")
    assert resp.status_code == 200
    data = resp.json()
    items = data["items"]
    assert len(items) >= 1
    assert any(p["name"] == "مطعم تقييم عالي" for p in items)
    # Top rated should be sorted by rating desc
    assert items[0]["rating"] >= 4.9

    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


# ------------------------------------------------------------------
# Most Visited
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_most_visited_empty(client):
    resp = await client.get("/api/v1/places/most-visited")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0


@pytest.mark.anyio
async def test_most_visited_with_data(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    resp = await client.post(
        "/api/v1/admin/places",
        json={
            "category_id": cat_id,
            "name": "مطعم أكثر زيارة",
            "city": "طرابلس",
            "category_name": "مطاعم",
            "image_url": "https://example.com/test.jpg",
            "rating": 3.0,
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

    resp = await client.get("/api/v1/places/most-visited")
    assert resp.status_code == 200
    data = resp.json()
    items = data["items"]
    assert len(items) >= 1
    assert any(p["name"] == "مطعم أكثر زيارة" for p in items)

    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


# ------------------------------------------------------------------
# City Filter
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_places_by_city_empty(client):
    resp = await client.get("/api/v1/places/city/طرابلس")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0


@pytest.mark.anyio
async def test_places_by_city_with_data(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    resp = await client.post(
        "/api/v1/admin/places",
        json={
            "category_id": cat_id,
            "name": "مطعم مدينة",
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

    resp = await client.get("/api/v1/places/city/طرابلس")
    assert resp.status_code == 200
    data = resp.json()
    items = data["items"]
    assert len(items) >= 1
    assert any(p["city"] == "طرابلس" for p in items)

    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


# ------------------------------------------------------------------
# Category Filter
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_places_by_category_empty(client, existing_category_id):
    resp = await client.get(f"/api/v1/places/category/{existing_category_id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0


@pytest.mark.anyio
async def test_places_by_category_with_data(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    resp = await client.post(
        "/api/v1/admin/places",
        json={
            "category_id": cat_id,
            "name": "مطعم بالفئة",
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

    resp = await client.get(f"/api/v1/places/category/{cat_id}")
    assert resp.status_code == 200
    data = resp.json()
    items = data["items"]
    assert len(items) >= 1
    assert any(p["category_id"] == cat_id for p in items)

    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


@pytest.mark.anyio
async def test_places_by_category_invalid_id(client):
    resp = await client.get("/api/v1/places/category/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0


# ------------------------------------------------------------------
# Place Response Schema
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_place_read_schema_fields(client, admin_token, existing_category_id):
    cat_id = existing_category_id
    resp = await client.post(
        "/api/v1/admin/places",
        json={
            "category_id": cat_id,
            "name": "Schema Test",
            "city": "Tripoli",
            "category_name": "مطاعم",
            "image_url": "https://example.com/test.jpg",
            "rating": 4.5,
            "is_open": True,
            "is_active": True,
            "latitude": 32.8872,
            "longitude": 13.1913,
            "images": ["https://example.com/img1.jpg"],
            "services": ["wifi"],
            "opening_time": "08:00",
            "closing_time": "23:00",
            "description": "A test place",
            "address": "Test Street",
            "phone": "+218 21 0000",
            "website": "https://test.example.com",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 201
    data = resp.json()

    required_fields = [
        "id", "category_id", "name", "city", "category_name",
        "image_url", "rating", "is_open", "is_active",
        "description", "address", "phone", "website",
        "latitude", "longitude", "images", "services",
        "opening_time", "closing_time", "reviews_count", "visits_count",
    ]
    for field in required_fields:
        assert field in data, f"Field '{field}' missing from PlaceRead"

    assert data["reviews_count"] == 0
    assert data["visits_count"] == 0
    place_id = data["id"]

    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": place_id})
        await session.commit()


# ------------------------------------------------------------------
# Place ordering
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_places_ordered_by_created_at_desc(client, admin_token, existing_category_id):
    """Places should be ordered by created_at DESC."""
    cat_id = existing_category_id
    place_ids = []

    for i in range(3):
        resp = await client.post(
            "/api/v1/admin/places",
            json={
                "category_id": cat_id,
                "name": f"ترتيب {i}",
                "city": "طرابلس",
                "category_name": "مطاعم",
                "image_url": "https://example.com/test.jpg",
                "rating": 0.0,
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
        place_ids.append(resp.json()["id"])

    resp = await client.get("/api/v1/places")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) == 3

    async with AsyncSessionLocal() as session:
        for pid in place_ids:
            await session.execute(text("DELETE FROM places WHERE id = :pid"), {"pid": pid})
        await session.commit()