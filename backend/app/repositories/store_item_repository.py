"""Store item repository."""

from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.store_item import StoreItem


class StoreItemRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def list_items(
        self,
        category_id: UUID | None = None,
        active_only: bool = False,
    ) -> list[StoreItem]:
        query = select(StoreItem)

        if category_id is not None:
            query = query.where(
                StoreItem.category_id == category_id
            )

        if active_only:
            now = datetime.now(timezone.utc)

            query = query.where(
                StoreItem.is_active.is_(True),
                (
                    StoreItem.available_from.is_(None)
                    | (StoreItem.available_from <= now)
                ),
                (
                    StoreItem.available_until.is_(None)
                    | (StoreItem.available_until >= now)
                ),
            )

        query = query.order_by(
            StoreItem.sort_order,
            StoreItem.created_at,
        )

        result = await self.session.execute(query)

        return result.scalars().all()

    async def get_item(
        self,
        item_id: UUID,
    ) -> StoreItem | None:
        result = await self.session.execute(
            select(StoreItem).where(
                StoreItem.id == item_id
            )
        )

        return result.scalar_one_or_none()

    async def create_item(
        self,
        item: StoreItem,
    ) -> StoreItem:
        self.session.add(item)

        await self.session.commit()
        await self.session.refresh(item)

        return item

    async def update_item(
        self,
        item: StoreItem,
    ) -> StoreItem:
        await self.session.commit()
        await self.session.refresh(item)

        return item

    async def delete_item(
        self,
        item: StoreItem,
    ) -> None:
        await self.session.delete(item)
        await self.session.commit()