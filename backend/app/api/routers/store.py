"""Store API routes — categories, items, and banners."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_permission
from app.core.database import get_session
from app.repositories.store_banner_repository import StoreBannerRepository
from app.repositories.store_category_repository import StoreCategoryRepository
from app.repositories.store_item_repository import StoreItemRepository
from app.schemas.store import (
    StoreBannerCreate,
    StoreBannerRead,
    StoreBannerUpdate,
    StoreCategoryCreate,
    StoreCategoryRead,
    StoreCategoryUpdate,
    StoreItemCreate,
    StoreItemRead,
    StoreItemUpdate,
)
from app.services.store_banner_service import StoreBannerService
from app.services.store_category_service import StoreCategoryService
from app.services.store_item_service import StoreItemService


router = APIRouter()


def _parse_uuid(
    entity_id: str,
    entity_name: str,
) -> UUID:
    """Validate UUID format to avoid DB errors for non-UUID strings."""
    try:
        return UUID(entity_id)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"{entity_name} not found",
        )


# ============================================================
# Public Store Categories
# ============================================================


@router.get(
    "/store/categories",
    response_model=list[StoreCategoryRead],
)
async def list_store_categories(
    active_only: bool = Query(
        default=False,
        description="Return only active categories",
    ),
    session: AsyncSession = Depends(get_session),
) -> list[StoreCategoryRead]:
    repository = StoreCategoryRepository(session)
    service = StoreCategoryService(repository)

    return await service.get_categories(
        active_only=active_only,
    )


@router.get(
    "/store/categories/{category_id}",
    response_model=StoreCategoryRead,
)
async def get_store_category(
    category_id: str,
    session: AsyncSession = Depends(get_session),
) -> StoreCategoryRead:
    category_uuid = _parse_uuid(
        category_id,
        "Store category",
    )

    repository = StoreCategoryRepository(session)
    service = StoreCategoryService(repository)

    category = await service.get_category(category_uuid)

    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store category not found",
        )

    return category


# ============================================================
# Public Store Items
# ============================================================


@router.get(
    "/store/items",
    response_model=list[StoreItemRead],
)
async def list_store_items(
    category_id: UUID | None = Query(
        default=None,
        description="Filter items by category",
    ),
    active_only: bool = Query(
        default=False,
        description="Return only active items",
    ),
    session: AsyncSession = Depends(get_session),
) -> list[StoreItemRead]:
    repository = StoreItemRepository(session)
    category_repository = StoreCategoryRepository(session)

    service = StoreItemService(
        repository,
        category_repository,
    )

    return await service.get_items(
        category_id=category_id,
        active_only=active_only,
    )


@router.get(
    "/store/items/{item_id}",
    response_model=StoreItemRead,
)
async def get_store_item(
    item_id: str,
    session: AsyncSession = Depends(get_session),
) -> StoreItemRead:
    item_uuid = _parse_uuid(
        item_id,
        "Store item",
    )

    repository = StoreItemRepository(session)
    category_repository = StoreCategoryRepository(session)

    service = StoreItemService(
        repository,
        category_repository,
    )

    item = await service.get_item(item_uuid)

    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store item not found",
        )

    return item


# ============================================================
# Public Store Banners
# ============================================================


@router.get(
    "/store/banners",
    response_model=list[StoreBannerRead],
)
async def list_store_banners(
    active_only: bool = Query(
        default=False,
        description="Return only active banners within their date window",
    ),
    session: AsyncSession = Depends(get_session),
) -> list[StoreBannerRead]:
    repository = StoreBannerRepository(session)
    service = StoreBannerService(repository)

    return await service.get_banners(
        active_only=active_only,
    )


@router.get(
    "/store/banners/{banner_id}",
    response_model=StoreBannerRead,
)
async def get_store_banner(
    banner_id: str,
    session: AsyncSession = Depends(get_session),
) -> StoreBannerRead:
    banner_uuid = _parse_uuid(
        banner_id,
        "Store banner",
    )

    repository = StoreBannerRepository(session)
    service = StoreBannerService(repository)

    banner = await service.get_banner(banner_uuid)

    if banner is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store banner not found",
        )

    return banner


# ============================================================
# Admin Store Categories
# ============================================================


@router.post(
    "/admin/store/categories",
    response_model=StoreCategoryRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(require_permission("store.write")),
    ],
)
async def create_admin_store_category(
    data: StoreCategoryCreate,
    session: AsyncSession = Depends(get_session),
) -> StoreCategoryRead:
    repository = StoreCategoryRepository(session)
    service = StoreCategoryService(repository)

    return await service.create_category(data)


@router.put(
    "/admin/store/categories/{category_id}",
    response_model=StoreCategoryRead,
    dependencies=[
        Depends(require_permission("store.write")),
    ],
)
async def update_admin_store_category(
    category_id: str,
    data: StoreCategoryUpdate,
    session: AsyncSession = Depends(get_session),
) -> StoreCategoryRead:
    category_uuid = _parse_uuid(
        category_id,
        "Store category",
    )

    repository = StoreCategoryRepository(session)
    service = StoreCategoryService(repository)

    category = await service.get_category(category_uuid)

    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store category not found",
        )

    return await service.update_category(
        category,
        data,
    )


@router.delete(
    "/admin/store/categories/{category_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[
        Depends(require_permission("store.delete")),
    ],
)
async def delete_admin_store_category(
    category_id: str,
    session: AsyncSession = Depends(get_session),
) -> None:
    category_uuid = _parse_uuid(
        category_id,
        "Store category",
    )

    repository = StoreCategoryRepository(session)
    service = StoreCategoryService(repository)

    category = await service.get_category(category_uuid)

    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store category not found",
        )

    await service.delete_category(category)


# ============================================================
# Admin Store Items
# ============================================================


@router.post(
    "/admin/store/items",
    response_model=StoreItemRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(require_permission("store.write")),
    ],
)
async def create_admin_store_item(
    data: StoreItemCreate,
    session: AsyncSession = Depends(get_session),
) -> StoreItemRead:
    repository = StoreItemRepository(session)
    category_repository = StoreCategoryRepository(session)

    service = StoreItemService(
        repository,
        category_repository,
    )

    try:
        item = await service.create_item(data)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return item


@router.put(
    "/admin/store/items/{item_id}",
    response_model=StoreItemRead,
    dependencies=[
        Depends(require_permission("store.write")),
    ],
)
async def update_admin_store_item(
    item_id: str,
    data: StoreItemUpdate,
    session: AsyncSession = Depends(get_session),
) -> StoreItemRead:
    item_uuid = _parse_uuid(
        item_id,
        "Store item",
    )

    repository = StoreItemRepository(session)
    category_repository = StoreCategoryRepository(session)

    service = StoreItemService(
        repository,
        category_repository,
    )

    item = await service.get_item(item_uuid)

    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store item not found",
        )

    try:
        return await service.update_item(
            item,
            data,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.delete(
    "/admin/store/items/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[
        Depends(require_permission("store.delete")),
    ],
)
async def delete_admin_store_item(
    item_id: str,
    session: AsyncSession = Depends(get_session),
) -> None:
    item_uuid = _parse_uuid(
        item_id,
        "Store item",
    )

    repository = StoreItemRepository(session)
    category_repository = StoreCategoryRepository(session)

    service = StoreItemService(
        repository,
        category_repository,
    )

    item = await service.get_item(item_uuid)

    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store item not found",
        )

    await service.delete_item(item)


# ============================================================
# Admin Store Banners
# ============================================================


@router.post(
    "/admin/store/banners",
    response_model=StoreBannerRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(require_permission("store.write")),
    ],
)
async def create_admin_store_banner(
    data: StoreBannerCreate,
    session: AsyncSession = Depends(get_session),
) -> StoreBannerRead:
    repository = StoreBannerRepository(session)
    service = StoreBannerService(repository)

    return await service.create_banner(data)


@router.put(
    "/admin/store/banners/{banner_id}",
    response_model=StoreBannerRead,
    dependencies=[
        Depends(require_permission("store.write")),
    ],
)
async def update_admin_store_banner(
    banner_id: str,
    data: StoreBannerUpdate,
    session: AsyncSession = Depends(get_session),
) -> StoreBannerRead:
    banner_uuid = _parse_uuid(
        banner_id,
        "Store banner",
    )

    repository = StoreBannerRepository(session)
    service = StoreBannerService(repository)

    banner = await service.get_banner(banner_uuid)

    if banner is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store banner not found",
        )

    return await service.update_banner(
        banner,
        data,
    )


@router.delete(
    "/admin/store/banners/{banner_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[
        Depends(require_permission("store.delete")),
    ],
)
async def delete_admin_store_banner(
    banner_id: str,
    session: AsyncSession = Depends(get_session),
) -> None:
    banner_uuid = _parse_uuid(
        banner_id,
        "Store banner",
    )

    repository = StoreBannerRepository(session)
    service = StoreBannerService(repository)

    banner = await service.get_banner(banner_uuid)

    if banner is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store banner not found",
        )

    await service.delete_banner(banner)