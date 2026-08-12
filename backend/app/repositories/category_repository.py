from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.category import Category


class CategoryRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def list_categories(self) -> list[Category]:
        result = await self.session.execute(
            select(Category).order_by(Category.sort_order)
        )
        return result.scalars().all()

    async def get_category(
        self,
        category_id: str,
    ) -> Category | None:
        result = await self.session.execute(
            select(Category).where(Category.id == category_id)
        )
        return result.scalar_one_or_none()

    async def create_category(
        self,
        category: Category,
    ) -> Category:
        self.session.add(category)

        await self.session.commit()

        await self.session.refresh(category)

        return category

    async def update_category(
        self,
        category: Category,
    ) -> Category:
        await self.session.commit()

        await self.session.refresh(category)

        return category

    async def delete_category(
        self,
        category: Category,
    ) -> None:
        await self.session.delete(category)

        await self.session.commit()