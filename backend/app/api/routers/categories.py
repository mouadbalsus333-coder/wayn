from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_permission
from app.core.database import get_session
from app.repositories.category_repository import CategoryRepository
from app.schemas.category import (
    CategoryCreate,
    CategoryRead,
    CategoryUpdate,
)
from app.services.category_service import CategoryService


router = APIRouter()


# ============================================================
# Public Categories
# ============================================================

@router.get(
    "/categories",
    response_model=list[CategoryRead],
)
async def list_categories(
    session: AsyncSession = Depends(get_session),
) -> list[CategoryRead]:
    repository = CategoryRepository(session)
    service = CategoryService(repository)

    return await service.get_categories()


@router.get(
    "/categories/{category_id}",
    response_model=CategoryRead,
)
async def get_category(
    category_id: str,
    session: AsyncSession = Depends(get_session),
) -> CategoryRead:
    repository = CategoryRepository(session)
    service = CategoryService(repository)

    category = await service.get_category(category_id)

    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found",
        )

    return category


# ============================================================
# Admin Categories
# ============================================================

@router.post(
    "/admin/categories",
    response_model=CategoryRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(require_permission("categories.write")),
    ],
)
async def create_admin_category(
    data: CategoryCreate,
    session: AsyncSession = Depends(get_session),
) -> CategoryRead:
    repository = CategoryRepository(session)
    service = CategoryService(repository)

    return await service.create_category(data)


@router.put(
    "/admin/categories/{category_id}",
    response_model=CategoryRead,
    dependencies=[
        Depends(require_permission("categories.write")),
    ],
)
async def update_admin_category(
    category_id: str,
    data: CategoryUpdate,
    session: AsyncSession = Depends(get_session),
) -> CategoryRead:
    repository = CategoryRepository(session)
    service = CategoryService(repository)

    category = await repository.get_category(category_id)

    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found",
        )

    return await service.update_category(
        category,
        data,
    )


@router.delete(
    "/admin/categories/{category_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[
        Depends(require_permission("categories.delete")),
    ],
)
async def delete_admin_category(
    category_id: str,
    session: AsyncSession = Depends(get_session),
) -> None:
    repository = CategoryRepository(session)
    service = CategoryService(repository)

    category = await repository.get_category(category_id)

    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found",
        )

    try:
        await service.delete_category(category)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc