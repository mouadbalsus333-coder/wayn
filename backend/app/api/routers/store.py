"""Store API routes — categories, items, and banners."""

from uuid import UUID, uuid4

from fastapi import (
    APIRouter,
    Depends,
    File,
    Header,
    HTTPException,
    Query,
    Request,
    UploadFile,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_permission
from app.api.dependencies.auth import get_current_user
from app.core.config import settings
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
    StoreOwnershipRead,
    StorePurchaseRead,
)
from app.models.user import User
from app.services.store_banner_service import StoreBannerService
from app.services.store_category_service import StoreCategoryService
from app.services.store_item_service import StoreItemService
from app.services.store_purchase_service import StorePurchaseService
from app.services.media.media_service import media_service


router = APIRouter()

_STORE_IMAGE_MAX_BYTES = 10 * 1024 * 1024
_STORE_IMAGE_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}


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


@router.post(
    "/store/items/{item_id}/purchase",
    response_model=StorePurchaseRead,
    status_code=status.HTTP_201_CREATED,
)
async def purchase_store_item(
    item_id: UUID,
    idempotency_key: str | None = Header(
        default=None,
        alias="Idempotency-Key",
    ),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> StorePurchaseRead:
    service = StorePurchaseService(session)

    try:
        result = await service.purchase(
            current_user.id,
            item_id,
            idempotency_key=idempotency_key,
        )
    except ValueError as exc:
        message = str(exc)
        not_found = message == "Store item not found"
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
                if not_found
                else status.HTTP_409_CONFLICT
            ),
            detail=message,
        ) from exc

    return StorePurchaseRead(
        id=result.purchase.id,
        item=result.item,
        currency=result.purchase.currency,
        amount=result.purchase.amount,
        quantity=result.purchase.quantity,
        owned_quantity=result.ownership.quantity,
        balance_after=result.balance_after,
        expires_at=result.ownership.expires_at,
        created_at=result.purchase.created_at,
    )


@router.get(
    "/store/ownership",
    response_model=list[StoreOwnershipRead],
)
async def list_store_ownership(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[StoreOwnershipRead]:
    ownerships = await StorePurchaseService(session).list_ownership(
        current_user.id,
    )

    return [
        StoreOwnershipRead(
            item=ownership.item,
            quantity=ownership.quantity,
            expires_at=ownership.expires_at,
        )
        for ownership in ownerships
    ]


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
    "/admin/store/media/image",
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(require_permission("store.write")),
    ],
)
async def upload_admin_store_image(
    request: Request,
    file: UploadFile = File(...),
) -> dict[str, str]:
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image filename is required",
        )

    extension = file.filename.rsplit(".", 1)[-1].lower()
    if extension not in _STORE_IMAGE_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPG, JPEG, PNG, and WEBP images are allowed",
        )

    file_bytes = await file.read(_STORE_IMAGE_MAX_BYTES + 1)
    if len(file_bytes) > _STORE_IMAGE_MAX_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Image size must not exceed 10 MB",
        )
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image file is empty",
        )

    object_key = f"store/{uuid4()}.webp"

    try:
        stored_key = media_service.upload_image(
            file_bytes=file_bytes,
            object_key=object_key,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image file",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Image upload failed",
        ) from exc

    if settings.r2_public_url:
        image_url = (
            f"{settings.r2_public_url.rstrip('/')}/"
            f"{stored_key.lstrip('/')}"
        )
    else:
        image_url = (
            f"{str(request.base_url).rstrip('/')}/"
            f"api/v1/media/{stored_key.lstrip('/')}"
        )

    return {"image_url": image_url}


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