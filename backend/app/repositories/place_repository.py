from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.place import Place, VerificationStatus


class PlaceRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def count_places(
        self,
        *,
        active_only: bool = True,
    ) -> int:
        """Count all places matching the given filters."""
        query = select(func.count()).select_from(Place)

        if active_only:
            query = query.where(
                Place.is_active.is_(True),
                Place.deleted_at.is_(None),
            )

        result = await self.session.execute(query)

        return result.scalar_one()

    async def list_places(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
        active_only: bool = True,
        sort_by: str | None = None,
        is_open: bool | None = None,
        category_ids: list[str] | None = None,
        latitude: float | None = None,
        longitude: float | None = None,
    ) -> tuple[list[Place], int]:
        """List active places with optional combined filters and sort.

        ``sort_by`` accepts one of the effective ordering criteria:
          - "reviews"  -> most reviewed first (reviews_count DESC)
          - "rating"   -> highest rated first (rating DESC)
          - "distance" -> nearest first (requires latitude/longitude)
          - default    -> created_at DESC

        ``is_open`` and ``category_ids`` are independent filters that can be
        combined with any ``sort_by``, so a single call can express e.g.
        open places, in selected categories, ordered by reviews.
        """
        conditions = []

        if active_only:
            conditions.append(Place.is_active.is_(True))
            conditions.append(Place.deleted_at.is_(None))

        if is_open is not None:
            conditions.append(Place.is_open.is_(is_open))

        if category_ids:
            conditions.append(Place.category_id.in_(category_ids))

        if sort_by == "distance":
            if latitude is None or longitude is None:
                raise ValueError(
                    "distance sort requires latitude and longitude"
                )
            user_location = func.ST_SetSRID(
                func.ST_MakePoint(longitude, latitude),
                4326,
            )
            user_geography = func.ST_GeogFromText(
                func.ST_AsText(user_location)
            )
            distance = func.ST_Distance(
                Place.location,
                user_geography,
            )
            conditions.append(Place.location.is_not(None))

        count_query = (
            select(func.count())
            .select_from(Place)
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        order_columns = []
        if sort_by == "reviews":
            order_columns = [
                Place.reviews_count.desc(),
                Place.rating.desc(),
            ]
        elif sort_by == "rating":
            order_columns = [
                Place.rating.desc(),
                Place.reviews_count.desc(),
            ]
        elif sort_by == "distance":
            order_columns = [distance.asc()]
        else:
            order_columns = [Place.created_at.desc()]

        query = (
            select(Place)
            .where(*conditions)
            .order_by(*order_columns)
            .offset(offset)
            .limit(limit)
        )

        result = await self.session.execute(query)

        return result.scalars().all(), total

    async def list_admin_places(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
        search: str | None = None,
        category_id: str | None = None,
        verification_status: VerificationStatus | None = None,
        owner_user_id: str | None = None,
        is_active: bool | None = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> tuple[list[Place], int]:
        sort_columns = {
            "created_at": Place.created_at,
            "updated_at": Place.updated_at,
            "name": Place.name,
            "rating": Place.rating,
            "reviews_count": Place.reviews_count,
            "visits_count": Place.visits_count,
        }
        sort_column = sort_columns[sort_by]
        order_expression = (
            sort_column.asc()
            if sort_order == "asc"
            else sort_column.desc()
        )

        conditions = []

        if search:
            pattern = f"%{search.strip()}%"
            conditions.append(
                or_(
                    Place.name.ilike(pattern),
                    Place.city.ilike(pattern),
                    Place.category_name.ilike(pattern),
                    Place.description.ilike(pattern),
                    Place.address.ilike(pattern),
                )
            )

        if category_id is not None:
            conditions.append(Place.category_id == category_id)

        if verification_status is not None:
            conditions.append(
                Place.verification_status == verification_status
            )

        if owner_user_id is not None:
            conditions.append(Place.owner_user_id == owner_user_id)

        if is_active is not None:
            conditions.append(Place.is_active == is_active)

        count_query = (
            select(func.count()).select_from(Place).where(*conditions)
        )
        total = int((await self.session.execute(count_query)).scalar_one())

        result = await self.session.execute(
            select(Place)
            .where(*conditions)
            .order_by(order_expression, Place.id.asc())
            .offset(offset)
            .limit(limit)
        )

        return list(result.scalars().all()), total

    async def get_place(
        self,
        place_id: str,
    ) -> Place | None:
        result = await self.session.execute(
            select(Place).where(
                Place.id == place_id,
                Place.deleted_at.is_(None),
            )
        )

        return result.scalar_one_or_none()

    async def list_places_by_category(
        self,
        category_id: str,
        *,
        offset: int = 0,
        limit: int = 20,
        active_only: bool = True,
    ) -> tuple[list[Place], int]:
        conditions = [
            Place.category_id == category_id,
        ]

        if active_only:
            conditions.extend([
                Place.is_active.is_(True),
                Place.deleted_at.is_(None),
            ])

        count_query = (
            select(func.count())
            .select_from(Place)
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        query = (
            select(Place)
            .where(*conditions)
            .order_by(Place.created_at.desc())
            .offset(offset)
            .limit(limit)
        )

        result = await self.session.execute(query)

        return result.scalars().all(), total

    async def search_places(
        self,
        query: str,
        *,
        offset: int = 0,
        limit: int = 20,
        active_only: bool = True,
    ) -> tuple[list[Place], int]:
        query = query.strip()

        if not query:
            return await self.list_places(
                offset=offset,
                limit=limit,
                active_only=active_only,
            )

        normalized = f"%{query}%"

        conditions = [
            or_(
                Place.name.ilike(normalized),
                Place.city.ilike(normalized),
                Place.category_name.ilike(normalized),
                Place.description.ilike(normalized),
                Place.address.ilike(normalized),
                Place.phone.ilike(normalized),
                Place.website.ilike(normalized),
            )
        ]

        if active_only:
            conditions.extend([
                Place.is_active.is_(True),
                Place.deleted_at.is_(None),
            ])

        count_query = (
            select(func.count())
            .select_from(Place)
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        statement = (
            select(Place)
            .where(*conditions)
            .order_by(
                Place.rating.desc(),
                Place.visits_count.desc(),
            )
            .offset(offset)
            .limit(limit)
        )

        result = await self.session.execute(statement)

        return result.scalars().all(), total

    async def list_open_places(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Place], int]:
        conditions = [
            Place.is_active.is_(True),
            Place.is_open.is_(True),
            Place.deleted_at.is_(None),
        ]

        count_query = (
            select(func.count())
            .select_from(Place)
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        result = await self.session.execute(
            select(Place)
            .where(*conditions)
            .order_by(
                Place.rating.desc(),
                Place.visits_count.desc(),
            )
            .offset(offset)
            .limit(limit)
        )

        return result.scalars().all(), total

    async def list_top_rated_places(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Place], int]:
        conditions = [
            Place.is_active.is_(True),
            Place.deleted_at.is_(None),
        ]

        count_query = (
            select(func.count())
            .select_from(Place)
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        result = await self.session.execute(
            select(Place)
            .where(*conditions)
            .order_by(
                Place.rating.desc(),
                Place.reviews_count.desc(),
            )
            .offset(offset)
            .limit(limit)
        )

        return result.scalars().all(), total

    async def list_most_visited_places(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Place], int]:
        conditions = [
            Place.is_active.is_(True),
            Place.deleted_at.is_(None),
        ]

        count_query = (
            select(func.count())
            .select_from(Place)
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        result = await self.session.execute(
            select(Place)
            .where(*conditions)
            .order_by(
                Place.reviews_count.desc(),
                Place.rating.desc(),
            )
            .offset(offset)
            .limit(limit)
        )

        return result.scalars().all(), total

    async def list_nearby_places(
        self,
        latitude: float,
        longitude: float,
        radius_meters: float,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Place], int]:
        """
        Return active places within the requested radius.

        ST_DWithin is used for the spatial filter so PostgreSQL/PostGIS
        can make effective use of the GiST spatial index on Place.location.

        ST_Distance is intentionally kept only for ordering the matching
        places by their actual distance from the requested point.
        """

        user_location = func.ST_SetSRID(
            func.ST_MakePoint(
                longitude,
                latitude,
            ),
            4326,
        )

        user_geography = func.ST_GeogFromText(
            func.ST_AsText(user_location)
        )

        distance = func.ST_Distance(
            Place.location,
            user_geography,
        )

        within_radius = func.ST_DWithin(
            Place.location,
            user_geography,
            radius_meters,
        )

        conditions = [
            Place.is_active.is_(True),
            Place.location.is_not(None),
            Place.deleted_at.is_(None),
            within_radius,
        ]

        count_query = (
            select(func.count())
            .select_from(Place)
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        result = await self.session.execute(
            select(Place)
            .where(*conditions)
            .order_by(
                distance.asc(),
            )
            .offset(offset)
            .limit(limit)
        )

        return result.scalars().all(), total

    async def list_places_by_city(
        self,
        city: str,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Place], int]:
        normalized_city = city.strip()

        conditions = [
            Place.is_active.is_(True),
            Place.city.ilike(
                normalized_city
            ),
            Place.deleted_at.is_(None),
        ]

        count_query = (
            select(func.count())
            .select_from(Place)
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        result = await self.session.execute(
            select(Place)
            .where(*conditions)
            .order_by(
                Place.rating.desc(),
                Place.visits_count.desc(),
            )
            .offset(offset)
            .limit(limit)
        )

        return result.scalars().all(), total

    async def create_place(
        self,
        place: Place,
    ) -> Place:
        self.session.add(place)

        await self.session.commit()

        await self.session.refresh(place)

        return place

    async def update_place(
        self,
        place: Place,
    ) -> Place:
        await self.session.commit()

        await self.session.refresh(place)

        return place

    async def delete_place(
        self,
        place: Place,
    ) -> None:
        await self.session.delete(place)

        await self.session.commit()
