"""Pagination validation tests for Places API endpoints."""
import pytest
from sqlalchemy import text

from app.core.database import AsyncSessionLocal


def _assert_paginated_response(data, *, total, page, limit, pages):
    """Assert that the response body is a valid PaginatedResponse."""
    assert isinstance(data, dict)
    assert "items" in data
    assert "total" in data
    assert "page" in data
    assert "limit" in data
    assert "pages" in data
    assert isinstance(data["items"], list)
    assert data["total"] == total
    assert data["page"] == page
    assert data["limit"] == limit
    assert data["pages"] == pages


@pytest.mark.anyio
async def test_list_places_page_zero_rejected(client):
    resp = await client.get("/api/v1/places?page=0")
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_list_places_limit_zero_rejected(client):
    resp = await client.get("/api/v1/places?limit=0")
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_list_places_limit_too_large_rejected(client):
    resp = await client.get("/api/v1/places?limit=101")
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_list_places_negative_page_rejected(client):
    resp = await client.get("/api/v1/places?page=-1")
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_list_places_negative_limit_rejected(client):
    resp = await client.get("/api/v1/places?limit=-5")
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_list_places_page_one_works(client):
    resp = await client.get("/api/v1/places?page=1&limit=100")
    assert resp.status_code == 200
    data = resp.json()
    _assert_paginated_response(data, total=0, page=1, limit=100, pages=0)


@pytest.mark.anyio
async def test_list_places_limit_one_returns_at_most_one(client):
    resp = await client.get("/api/v1/places?limit=1&page=1")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) <= 1


@pytest.mark.anyio
async def test_search_pagination(client):
    """Search endpoint should respect pagination params."""
    resp = await client.get("/api/v1/places/search?q=&page=1&limit=10")
    assert resp.status_code == 200
    data = resp.json()
    _assert_paginated_response(data, total=0, page=1, limit=10, pages=0)


@pytest.mark.anyio
async def test_search_page_zero_rejected(client):
    resp = await client.get("/api/v1/places/search?q=test&page=0")
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_search_limit_too_large_rejected(client):
    resp = await client.get("/api/v1/places/search?q=test&limit=101")
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_open_places_pagination(client):
    resp = await client.get("/api/v1/places/open?page=1&limit=10")
    assert resp.status_code == 200
    data = resp.json()
    _assert_paginated_response(data, total=0, page=1, limit=10, pages=0)


@pytest.mark.anyio
async def test_top_rated_pagination(client):
    resp = await client.get("/api/v1/places/top-rated?page=1&limit=10")
    assert resp.status_code == 200
    data = resp.json()
    _assert_paginated_response(data, total=0, page=1, limit=10, pages=0)


@pytest.mark.anyio
async def test_most_visited_pagination(client):
    resp = await client.get("/api/v1/places/most-visited?page=1&limit=10")
    assert resp.status_code == 200
    data = resp.json()
    _assert_paginated_response(data, total=0, page=1, limit=10, pages=0)


@pytest.mark.anyio
async def test_nearby_pagination(client):
    resp = await client.get(
        "/api/v1/places/nearby",
        params={"latitude": 32.0, "longitude": 13.0, "page": 1, "limit": 10},
    )
    assert resp.status_code == 200
    data = resp.json()
    _assert_paginated_response(data, total=0, page=1, limit=10, pages=0)


@pytest.mark.anyio
async def test_category_places_pagination(client, existing_category_id):
    resp = await client.get(
        f"/api/v1/places/category/{existing_category_id}?page=1&limit=10"
    )
    assert resp.status_code == 200
    data = resp.json()
    _assert_paginated_response(data, total=0, page=1, limit=10, pages=0)


@pytest.mark.anyio
async def test_city_places_pagination(client):
    resp = await client.get(
        "/api/v1/places/city/طرابلس?page=1&limit=10"
    )
    assert resp.status_code == 200
    data = resp.json()
    _assert_paginated_response(data, total=0, page=1, limit=10, pages=0)


@pytest.mark.anyio
async def test_invalid_page_returns_422(client):
    resp = await client.get("/api/v1/places?page=abc")
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_invalid_limit_returns_422(client):
    resp = await client.get("/api/v1/places?limit=abc")
    assert resp.status_code == 422


# ==================================================================
# Pagination metadata body
# ==================================================================


@pytest.mark.anyio
async def test_list_places_pagination_body_empty(client):
    """Empty DB -> total=0, pages=0, items=[]."""
    resp = await client.get("/api/v1/places?page=1&limit=20")
    assert resp.status_code == 200
    data = resp.json()
    _assert_paginated_response(data, total=0, page=1, limit=20, pages=0)
    assert data["items"] == []


@pytest.mark.anyio
async def test_list_places_pagination_body_with_data(
    client, admin_token, existing_category_id
):
    """Create 5 places -> total=5, pages=1 with limit=20."""
    cat_id = existing_category_id
    place_ids = []

    for i in range(5):
        resp = await client.post(
            "/api/v1/admin/places",
            json={
                "category_id": cat_id,
                "name": f"مطعم pagination {i}",
                "city": "طرابلس",
                "category_name": "مطاعم",
                "image_url": "https://example.com/test.jpg",
                "rating": float(i),
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

    resp = await client.get("/api/v1/places?page=1&limit=20")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) == 5
    _assert_paginated_response(data, total=5, page=1, limit=20, pages=1)

    # Cleanup
    async with AsyncSessionLocal() as session:
        for pid in place_ids:
            await session.execute(
                text("DELETE FROM places WHERE id = :pid"), {"pid": pid}
            )
        await session.commit()


@pytest.mark.anyio
async def test_list_places_pagination_body_multiple_pages(
    client, admin_token, existing_category_id
):
    """Create 5 places -> with limit=2, pages=3, page=2 returns 2 items."""
    cat_id = existing_category_id
    place_ids = []

    for i in range(5):
        resp = await client.post(
            "/api/v1/admin/places",
            json={
                "category_id": cat_id,
                "name": f"مطعم pages {i}",
                "city": "طرابلس",
                "category_name": "مطاعم",
                "image_url": "https://example.com/test.jpg",
                "rating": float(i),
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

    # Page 1 with limit=2 -> 2 items, total=5, pages=3
    resp = await client.get("/api/v1/places?page=1&limit=2")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) == 2
    _assert_paginated_response(data, total=5, page=1, limit=2, pages=3)

    # Page 2 with limit=2 -> 2 items, total=5, pages=3
    resp = await client.get("/api/v1/places?page=2&limit=2")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) == 2
    _assert_paginated_response(data, total=5, page=2, limit=2, pages=3)

    # Page 3 with limit=2 -> 1 item, total=5, pages=3
    resp = await client.get("/api/v1/places?page=3&limit=2")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) == 1
    _assert_paginated_response(data, total=5, page=3, limit=2, pages=3)

    # Cleanup
    async with AsyncSessionLocal() as session:
        for pid in place_ids:
            await session.execute(
                text("DELETE FROM places WHERE id = :pid"), {"pid": pid}
            )
        await session.commit()


@pytest.mark.anyio
async def test_pagination_body_total_not_just_page_length(
    client, admin_token, existing_category_id
):
    """total must reflect ALL matching items, not just the current page length."""
    cat_id = existing_category_id
    place_ids = []

    for i in range(7):
        resp = await client.post(
            "/api/v1/admin/places",
            json={
                "category_id": cat_id,
                "name": f"مطعم total {i}",
                "city": "طرابلس",
                "category_name": "مطاعم",
                "image_url": "https://example.com/test.jpg",
                "rating": float(i),
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

    # limit=3 -> page 1 has 3 items, but total must be 7
    resp = await client.get("/api/v1/places?page=1&limit=3")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) == 3
    _assert_paginated_response(data, total=7, page=1, limit=3, pages=3)

    # Cleanup
    async with AsyncSessionLocal() as session:
        for pid in place_ids:
            await session.execute(
                text("DELETE FROM places WHERE id = :pid"), {"pid": pid}
            )
        await session.commit()