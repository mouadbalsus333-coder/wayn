import math
from datetime import datetime
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_permission
from app.core.database import get_session
from app.schemas.pagination import PaginatedResponse
from app.schemas.review import ReviewRead
from app.services.review_service import ReviewService


class ReviewVisibilityUpdate(BaseModel):
    is_visible: bool


router = APIRouter(
    prefix="/admin/reviews",
    tags=["Admin Reviews"],
)


@router.get(
    "",
    response_model=PaginatedResponse[ReviewRead],
    dependencies=[Depends(require_permission("reviews.read"))],
)
async def list_admin_reviews(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    place_id: str | None = Query(default=None),
    rating: Decimal | None = Query(default=None, ge=1, le=5),
    is_visible: bool | None = Query(default=None),
    search: str | None = Query(default=None, max_length=255),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    session: AsyncSession = Depends(get_session),
) -> PaginatedResponse[ReviewRead]:
    items, total = await ReviewService(session).list_admin_reviews(
        offset=(page - 1) * limit,
        limit=limit,
        place_id=place_id,
        rating=rating,
        is_visible=is_visible,
        search=search,
        created_from=created_from,
        created_to=created_to,
    )
    return PaginatedResponse(
        items=items,
        total=total,
        page=page,
        limit=limit,
        pages=math.ceil(total / limit) if total else 0,
    )


@router.patch(
    "/{review_id}/visibility",
    response_model=ReviewRead,
    dependencies=[Depends(require_permission("reviews.moderate"))],
)
async def update_review_visibility(
    review_id: UUID,
    data: ReviewVisibilityUpdate,
    session: AsyncSession = Depends(get_session),
) -> ReviewRead:
    service = ReviewService(session)
    review = await service.repo.get_review_by_id(review_id)
    if review is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Review not found",
        )
    return await service.set_visibility(review, data.is_visible)