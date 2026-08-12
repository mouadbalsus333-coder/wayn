from app.models.category import Category
from app.repositories.category_repository import CategoryRepository
from app.schemas.category import CategoryCreate, CategoryUpdate


class CategoryService:
    def __init__(self, repository: CategoryRepository):
        self.repository = repository

    async def get_categories(self) -> list[Category]:
        return await self.repository.list_categories()

    async def get_category(
        self,
        category_id: str,
    ) -> Category | None:
        return await self.repository.get_category(category_id)

    async def create_category(
        self,
        data: CategoryCreate,
    ) -> Category:
        category = Category(
            name_ar=data.name_ar,
            name_en=data.name_en,
            icon=data.icon,
            sort_order=data.sort_order,
            is_active=data.is_active,
        )

        return await self.repository.create_category(category)

    async def update_category(
        self,
        category: Category,
        data: CategoryUpdate,
    ) -> Category:
        update_data = data.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            setattr(category, field, value)

        return await self.repository.update_category(category)

    async def delete_category(
        self,
        category: Category,
    ) -> None:
        await self.repository.delete_category(category)