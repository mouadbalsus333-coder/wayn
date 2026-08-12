from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_permission
from app.core.database import get_session
from app.repositories.category_repository import CategoryRepository
from app.repositories.place_repository import PlaceRepository
from app.schemas.place import PlaceCreate, PlaceRead, PlaceUpdate
from app.services.place_service import PlaceService

router = APIRouter(
    prefix="/admin/places",
    tags=["Admin Places"],
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
