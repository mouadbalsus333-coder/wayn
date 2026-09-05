"""Repository for place_reviews table operations."""

from decimal import Decimal
from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.place import Place
from app.models.review import PlaceReview


class ReviewRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_review(
        self,
        user_id: UUID | str,
        place_id: UUID | str,
    ) -> PlaceReview | None:
        result = await self.session.execute(
            select(PlaceReview).where(
                PlaceReview.user_id == str(user_id),
                PlaceReview.place_id == str(place_id),
            )
        )
        return result.scalar_one_or_none()

    async def get_review_by_id(
        self,
        review_id: UUID | str,
    ) -> PlaceReview | None:
        result = await self.session.execute(
            select(PlaceReview).where(
                PlaceReview.id == str(review_id),
            )
        )
        return result.scalar_one_or_none()

    async def list_place_reviews(
        self,
        place_id: UUID | str,
        *,
        visible_only: bool = True,
        offset: int = 0,
        limit: int = 20,
    ) -> list[PlaceReview]:
        query = select(PlaceReview).where(
            PlaceReview.place_id == str(place_id),
        )
        if visible_only:
            query = query.where(PlaceReview.is_visible.is_(True))
        query = query.order_by(PlaceReview.created_at.desc()).offset(offset).limit(limit)
        result = await self.session.execute(query)
        return result.scalars().all()

    async def list_admin_reviews(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
        place_id: str | None = None,
        rating: Decimal | None = None,
        is_visible: bool | None = None,
        search: str | None = None,
        created_from=None,
        created_to=None,
    ) -> tuple[list[PlaceReview], int]:
        conditions = []
        if place_id is not None:
            conditions.append(PlaceReview.place_id == str(place_id))
        if rating is not None:
            conditions.append(PlaceReview.rating == rating)
        if is_visible is not None:
            conditions.append(PlaceReview.is_visible == is_visible)
        if search:
            conditions.append(PlaceReview.comment.ilike(f"%{search.strip()}%"))
        if created_from is not None:
            conditions.append(PlaceReview.created_at >= created_from)
        if created_to is not None:
            conditions.append(PlaceReview.created_at <= created_to)

        total = int(
            (
                await self.session.execute(
                    select(func.count()).select_from(PlaceReview).where(*conditions)
                )
            ).scalar_one()
        )
        result = await self.session.execute(
            select(PlaceReview)
            .where(*conditions)
            .order_by(PlaceReview.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return list(result.scalars().all()), total

    async def create_review(self, review: PlaceReview) -> PlaceReview:
        self.session.add(review)
        await self.session.flush()  # get the ID before committing
        await self._update_place_aggregates(review.place_id)
        await self.session.commit()
        await self.session.refresh(review)
        return review

    async def update_review(self, review: PlaceReview) -> PlaceReview:
        await self.session.flush()
        await self._update_place_aggregates(review.place_id)
        await self.session.commit()
        await self.session.refresh(review)
        return review

    async def delete_review(self, review: PlaceReview) -> None:
        place_id = review.place_id
        await self.session.delete(review)
        await self.session.flush()
        await self._update_place_aggregates(place_id)
        await self.session.commit()

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _update_place_aggregates(self, place_id: str) -> None:
        """Recalculate and persist denormalized rating + reviews_count on Place.

        Called after every create / update / delete / visibility change so that
        places.rating and places.reviews_count always reflect the current
        set of visible reviews stored in place_reviews.
        """
        agg_result = await self.session.execute(
            select(
                func.count(PlaceReview.id).label("cnt"),
                func.coalesce(
                    func.avg(PlaceReview.rating), 0
                ).label("avg_rating"),
            ).where(
                PlaceReview.place_id == place_id,
                PlaceReview.is_visible.is_(True),
            )
        )
        row = agg_result.one()
        cnt: int = int(row.cnt)
        avg_rating: float = float(row.avg_rating)

        # Round to one decimal place to match NUMERIC(2,1) precision.
        avg_rating = round(avg_rating, 1)

        place_result = await self.session.execute(
            select(Place).where(Place.id == place_id)
        )
        place = place_result.scalar_one_or_none()
        if place is not None:
            place.reviews_count = cnt
            place.rating = avg_rating
            self.session.add(place)
