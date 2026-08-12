"""Place reviews endpoints."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.models.user import User
from app.schemas.review import ReviewCreate, ReviewRead, ReviewUpdate
from app.services.review_service import ReviewService

router = APIRouter(tags=["reviews"])


@router.get(
    "/places/{place_id}/reviews",
    response_model=list[ReviewRead],
    summary="Get all visible reviews for a place",
)
async def get_place_reviews(
    place_id: str,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
):
    service = ReviewService(session)
    return await service.get_place_reviews(
        place_id,
        offset=offset,
        limit=limit,
    )


@router.post(
    "/places/{place_id}/reviews",
    response_model=ReviewRead,
    status_code=201,
    summary="Submit a new review for a place (one per user per place)",
)
async def create_review(
    place_id: str,
    data: ReviewCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    service = ReviewService(session)
    return await service.create_review(
        user_id=current_user.id,
        place_id=place_id,
        data=data,
    )


@router.put(
    "/places/{place_id}/reviews",
    response_model=ReviewRead,
    summary="Update the current user's review for a place",
)
async def update_review(
    place_id: str,
    data: ReviewUpdate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    service = ReviewService(session)
    return await service.update_review(
        user_id=current_user.id,
        place_id=place_id,
        data=data,
    )


@router.delete(
    "/places/{place_id}/reviews",
    status_code=204,
    summary="Delete the current user's review for a place",
)
async def delete_review(
    place_id: str,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    service = ReviewService(session)
    await service.delete_review(
        user_id=current_user.id,
        place_id=place_id,
    )
