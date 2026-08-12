import pytest
from httpx import AsyncClient

from app.main import app
from app.api import routers as api_routers


class DummyCategory:
    def __init__(
        self,
        id: str,
        name_ar: str,
        name_en: str | None,
        icon: str | None,
        sort_order: int,
        is_active: bool,
        parent_id: str | None = None,
    ):
        self.id = id
        self.name_ar = name_ar
        self.name_en = name_en
        self.icon = icon
        self.sort_order = sort_order
        self.is_active = is_active
        self.parent_id = parent_id


class DummyCategoryRepository:
    async def list_categories(self):
        return [
            DummyCategory(
                id="cat-1",
                name_ar="مطعم",
                name_en="Restaurant",
                icon="restaurant",
                sort_order=1,
                is_active=True,
                parent_id=None,
            )
        ]


@pytest.mark.anyio
async def test_list_categories_returns_category_list(monkeypatch):
    monkeypatch.setattr(
        api_routers.categories,
        "CategoryRepository",
        lambda session: DummyCategoryRepository(),
    )

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        response = await client.get(
            "/api/v1/categories"
        )

    assert response.status_code == 200

    assert response.json() == [
        {
            "id": "cat-1",
            "name_ar": "مطعم",
            "name_en": "Restaurant",
            "icon": "restaurant",
            "sort_order": 1,
            "is_active": True,
            "parent_id": None,
        }
    ]