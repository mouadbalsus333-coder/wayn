import math
from typing import Literal

from fastapi import APIRouter, Depends, Query, Response, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_permission
from app.core.database import get_session
from app.repositories.category_repository import CategoryRepository
from app.repositories.place_repository import PlaceRepository
from app.models.place import VerificationStatus
from app.schemas.pagination import PaginatedResponse
from app.schemas.place import PlaceCreate, PlaceRead, PlaceUpdate
from app.services.place_service import PlaceService

router = APIRouter(
    prefix="/admin/places",
    tags=["Admin Places"],
)


@router.get(
    "",
    response_model=PaginatedResponse[PlaceRead],
    dependencies=[
        Depends(require_permission("places.read")),
    ],
)
async def list_admin_places(
    response: Response,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    search: str | None = Query(default=None, max_length=255),
    category_id: str | None = Query(default=None),
    verification_status: VerificationStatus | None = Query(default=None),
    owner_user_id: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    sort_by: Literal[
        "created_at",
        "updated_at",
        "name",
        "rating",
        "reviews_count",
        "visits_count",
    ] = Query(default="created_at"),
    sort_order: Literal["asc", "desc"] = Query(default="desc"),
    session: AsyncSession = Depends(get_session),
) -> PaginatedResponse[PlaceRead]:
    service = PlaceService(
        PlaceRepository(session),
        CategoryRepository(session),
    )
    offset = (page - 1) * limit
    places, total = await service.get_admin_places(
        offset=offset,
        limit=limit,
        search=search,
        category_id=category_id,
        verification_status=verification_status,
        owner_user_id=owner_user_id,
        is_active=is_active,
        sort_by=sort_by,
        sort_order=sort_order,
    )
    pages = math.ceil(total / limit) if total else 0
    response.headers["X-Total-Count"] = str(total)
    return PaginatedResponse[PlaceRead](
        items=places,
        total=total,
        page=page,
        limit=limit,
        pages=pages,
    )


@router.post(
    "",
    response_model=PlaceRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(require_permission("places.write")),
    ],
)
async def create_admin_place(
    data: PlaceCreate,
    session: AsyncSession = Depends(get_session),
) -> PlaceRead:
    place_repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        place_repository,
        category_repository,
    )

    try:
        place = await service.create_place(data)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return place


@router.put(
    "/{place_id}",
    response_model=PlaceRead,
    dependencies=[
        Depends(require_permission("places.write")),
    ],
)
async def update_admin_place(
    place_id: str,
    data: PlaceUpdate,
    session: AsyncSession = Depends(get_session),
) -> PlaceRead:
    place_repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        place_repository,
        category_repository,
    )

    place = await place_repository.get_place(place_id)

    if place is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Place not found",
        )

    return await service.update_place(
        place,
        data,
    )


@router.delete(
    "/{place_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[
        Depends(require_permission("places.delete")),
    ],
)
async def delete_admin_place(
    place_id: str,
    session: AsyncSession = Depends(get_session),
) -> None:
    place_repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        place_repository,
        category_repository,
    )

    place = await place_repository.get_place(place_id)

    if place is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Place not found",
        )

    await service.delete_place(place)
