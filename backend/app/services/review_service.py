"""Service layer for place reviews."""

from decimal import Decimal
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.review import PlaceReview
from app.repositories.place_repository import PlaceRepository
from app.repositories.review_repository import ReviewRepository
from app.schemas.review import ReviewCreate, ReviewUpdate


class ReviewService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repo = ReviewRepository(session)
        self.place_repo = PlaceRepository(session)

    async def _get_active_place(self, place_id: str):
        place = await self.place_repo.get_place(place_id)
        if place is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Place not found",
            )
        return place

    async def create_review(
        self,
        user_id: UUID | str,
        place_id: str,
        data: ReviewCreate,
    ) -> PlaceReview:
        await self._get_active_place(place_id)

        existing = await self.repo.get_review(user_id, place_id)
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You have already reviewed this place. Use PUT to update your review.",
            )

        review = PlaceReview(
            place_id=str(place_id),
            user_id=str(user_id),
            rating=data.rating,
            comment=data.comment,
            images=data.images,
        )
        return await self.repo.create_review(review)

    async def update_review(
        self,
        user_id: UUID | str,
        place_id: str,
        data: ReviewUpdate,
    ) -> PlaceReview:
        review = await self.repo.get_review(user_id, place_id)
        if review is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Review not found",
            )

        if data.rating is not None:
            review.rating = data.rating
        if data.comment is not None:
            review.comment = data.comment
        if data.images is not None:
            review.images = data.images
        if data.is_visible is not None:
            review.is_visible = data.is_visible

        return await self.repo.update_review(review)

    async def delete_review(
        self,
        user_id: UUID | str,
        place_id: str,
    ) -> None:
        review = await self.repo.get_review(user_id, place_id)
        if review is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Review not found",
            )
        await self.repo.delete_review(review)

    async def get_place_reviews(
        self,
        place_id: str,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> list[PlaceReview]:
        await self._get_active_place(place_id)
        return await self.repo.list_place_reviews(
            place_id,
            visible_only=True,
            offset=offset,
            limit=limit,
        )

    async def list_admin_reviews(self, **filters):
        return await self.repo.list_admin_reviews(**filters)

    async def set_visibility(
        self,
        review: PlaceReview,
        is_visible: bool,
    ) -> PlaceReview:
        review.is_visible = is_visible
        return await self.repo.update_review(review)
