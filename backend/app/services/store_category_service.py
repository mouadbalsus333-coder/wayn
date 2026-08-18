"""Store category service."""

from uuid import UUID

from app.models.store_category import StoreCategory
from app.repositories.store_category_repository import (
    StoreCategoryRepository,
)
from app.schemas.store import (
    StoreCategoryCreate,
    StoreCategoryUpdate,
)


class StoreCategoryService:
    def __init__(
        self,
        repository: StoreCategoryRepository,
    ):
        self.repository = repository

    async def get_categories(
        self,
        active_only: bool = False,
    ) -> list[StoreCategory]:
        return await self.repository.list_categories(
            active_only=active_only,
        )

    async def get_category(
        self,
        category_id: UUID,
    ) -> StoreCategory | None:
        return await self.repository.get_category(
            category_id,
        )

    async def create_category(
        self,
        data: StoreCategoryCreate,
    ) -> StoreCategory:
        category = StoreCategory(
            name_ar=data.name_ar,
            name_en=data.name_en,
            description_ar=data.description_ar,
            description_en=data.description_en,
            icon_url=data.icon_url,
            image_url=data.image_url,
            sort_order=data.sort_order,
            is_active=data.is_active,
        )

        return await self.repository.create_category(
            category,
        )

    async def update_category(
        self,
        category: StoreCategory,
        data: StoreCategoryUpdate,
    ) -> StoreCategory:
        update_data = data.model_dump(
            exclude_unset=True,
        )

        for field, value in update_data.items():
            setattr(category, field, value)

        return await self.repository.update_category(
            category,
        )

    async def delete_category(
        self,
        category: StoreCategory,
    ) -> None:
        await self.repository.delete_category(
            category,
        )