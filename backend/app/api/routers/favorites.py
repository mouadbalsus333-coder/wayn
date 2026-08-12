"""Favorites endpoints — requires authenticated user."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.models.user import User
from app.schemas.favorite import FavoriteRead
from app.schemas.place import PlaceRead
from app.services.favorite_service import FavoriteService

router = APIRouter(prefix="/favorites", tags=["favorites"])


@router.post(
    "/{place_id}",
    response_model=FavoriteRead,
    status_code=201,
    summary="Add a place to the current user's favorites",
)
async def add_favorite(
    place_id: str,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    service = FavoriteService(session)
    favorite = await service.add_favorite(
        user_id=current_user.id,
        place_id=place_id,
    )
    return favorite


@router.delete(
    "/{place_id}",
    status_code=204,
    summary="Remove a place from the current user's favorites",
)
async def remove_favorite(
    place_id: str,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    service = FavoriteService(session)
    await service.remove_favorite(
        user_id=current_user.id,
        place_id=place_id,
    )


@router.get(
    "",
    response_model=list[PlaceRead],
    summary="Get the current user's saved places",
)
async def get_my_favorites(
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    service = FavoriteService(session)
    places = await service.get_user_favorites(
        user_id=current_user.id,
        offset=offset,
        limit=limit,
    )
    return places


@router.get(
    "/{place_id}/check",
    summary="Check if a specific place is in the current user's favorites",
)
async def check_favorite(
    place_id: str,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    service = FavoriteService(session)
    is_fav = await service.is_favorite(
        user_id=current_user.id,
        place_id=place_id,
    )
    return {"place_id": place_id, "is_favorite": is_fav}
