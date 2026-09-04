"""Store item service."""

from uuid import UUID

from app.models.store_item import StoreItem
from app.repositories.store_category_repository import (
    StoreCategoryRepository,
)
from app.repositories.store_item_repository import (
    StoreItemRepository,
)
from app.schemas.store import (
    StoreItemCreate,
    StoreItemUpdate,
)


class StoreItemService:
    def __init__(
        self,
        repository: StoreItemRepository,
        category_repository: StoreCategoryRepository,
    ):
        self.repository = repository
        self.category_repository = category_repository

    async def get_items(
        self,
        category_id: UUID | None = None,
        active_only: bool = False,
    ) -> list[StoreItem]:
        return await self.repository.list_items(
            category_id=category_id,
            active_only=active_only,
        )

    async def get_item(
        self,
        item_id: UUID,
    ) -> StoreItem | None:
        return await self.repository.get_item(
            item_id,
        )

    async def create_item(
        self,
        data: StoreItemCreate,
    ) -> StoreItem:
        category = await self.category_repository.get_category(
            data.category_id,
        )

        if category is None:
            raise ValueError("Store category not found")

        item = StoreItem(
            category_id=data.category_id,
            name_ar=data.name_ar,
            name_en=data.name_en,
            description_ar=data.description_ar,
            description_en=data.description_en,
            item_type=data.item_type,
            currency=data.currency,
            price=data.price,
            image_url=data.image_url,
            asset_id=data.asset_id,
            duration_days=data.duration_days,
            available_from=data.available_from,
            available_until=data.available_until,
            ownership_duration_days=data.ownership_duration_days,
            stock=data.stock,
            sort_order=data.sort_order,
            is_active=data.is_active,
        )

        return await self.repository.create_item(
            item,
        )

    async def update_item(
        self,
        item: StoreItem,
        data: StoreItemUpdate,
    ) -> StoreItem:
        update_data = data.model_dump(
            exclude_unset=True,
        )

        if "category_id" in update_data:
            category_id = update_data["category_id"]

            category = await self.category_repository.get_category(
                category_id,
            )

            if category is None:
                raise ValueError("Store category not found")

        for field, value in update_data.items():
            setattr(item, field, value)

        return await self.repository.update_item(
            item,
        )

    async def delete_item(
        self,
        item: StoreItem,
    ) -> None:
        await self.repository.delete_item(
            item,
        )