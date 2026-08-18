"""Store category repository."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.store_category import StoreCategory


class StoreCategoryRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def list_categories(
        self,
        active_only: bool = False,
    ) -> list[StoreCategory]:
        query = select(StoreCategory)

        if active_only:
            query = query.where(
                StoreCategory.is_active.is_(True)
            )

        query = query.order_by(
            StoreCategory.sort_order,
            StoreCategory.created_at,
        )

        result = await self.session.execute(query)

        return result.scalars().all()

    async def get_category(
        self,
        category_id: UUID,
    ) -> StoreCategory | None:
        result = await self.session.execute(
            select(StoreCategory).where(
                StoreCategory.id == category_id
            )
        )

        return result.scalar_one_or_none()

    async def create_category(
        self,
        category: StoreCategory,
    ) -> StoreCategory:
        self.session.add(category)

        await self.session.commit()
        await self.session.refresh(category)

        return category

    async def update_category(
        self,
        category: StoreCategory,
    ) -> StoreCategory:
        await self.session.commit()
        await self.session.refresh(category)

        return category

    async def delete_category(
        self,
        category: StoreCategory,
    ) -> None:
        await self.session.delete(category)
        await self.session.commit()