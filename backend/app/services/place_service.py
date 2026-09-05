from geoalchemy2.elements import WKTElement

from app.models.place import Place, VerificationStatus
from app.repositories.category_repository import CategoryRepository
from app.repositories.place_repository import PlaceRepository
from app.schemas.place import PlaceCreate, PlaceUpdate


class PlaceService:
    def __init__(
        self,
        repository: PlaceRepository,
        category_repository: CategoryRepository,
    ):
        self.repository = repository
        self.category_repository = category_repository

    # ============================================================
    # Public / Read
    # ============================================================

    async def get_places(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
        active_only: bool = True,
    ) -> tuple[list[Place], int]:
        return await self.repository.list_places(
            offset=offset,
            limit=limit,
            active_only=active_only,
        )

    async def get_admin_places(
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
        return await self.repository.list_admin_places(
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

    async def get_place_by_id(
        self,
        place_id: str,
    ) -> Place | None:
        return await self.repository.get_place(place_id)

    async def get_places_by_category(
        self,
        category_id: str,
        *,
        offset: int = 0,
        limit: int = 20,
        active_only: bool = True,
    ) -> tuple[list[Place], int]:
        return await self.repository.list_places_by_category(
            category_id,
            offset=offset,
            limit=limit,
            active_only=active_only,
        )

    async def search_places(
        self,
        query: str,
        *,
        offset: int = 0,
        limit: int = 20,
        active_only: bool = True,
    ) -> tuple[list[Place], int]:
        return await self.repository.search_places(
            query,
            offset=offset,
            limit=limit,
            active_only=active_only,
        )

    async def get_open_places(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Place], int]:
        return await self.repository.list_open_places(
            offset=offset,
            limit=limit,
        )

    async def get_highest_rated_places(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Place], int]:
        return await self.repository.list_top_rated_places(
            offset=offset,
            limit=limit,
        )

    async def get_most_visited_places(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Place], int]:
        return await self.repository.list_most_visited_places(
            offset=offset,
            limit=limit,
        )

    async def get_nearby_places(
        self,
        latitude: float,
        longitude: float,
        radius_meters: float,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Place], int]:
        return await self.repository.list_nearby_places(
            latitude=latitude,
            longitude=longitude,
            radius_meters=radius_meters,
            offset=offset,
            limit=limit,
        )

    async def get_places_by_city(
        self,
        city: str,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Place], int]:
        return await self.repository.list_places_by_city(
            city,
            offset=offset,
            limit=limit,
        )

    # ============================================================
    # Helpers
    # ============================================================

    async def _get_category_or_none(
        self,
        category_id: str | None,
    ):
        if category_id is None:
            return None

        return await self.category_repository.get_category(
            category_id
        )

    # ============================================================
    # Create
    # ============================================================

    async def create_place(
        self,
        data: PlaceCreate,
    ) -> Place:

        category = await self._get_category_or_none(
            data.category_id
        )

        if data.category_id is not None and category is None:
            raise ValueError("Category not found")

        category_name = data.category_name

        if category is not None:
            # WAYN is Arabic-first — prefer the Arabic name when available.
            category_name = (
                category.name_ar
                or category.name_en
            )

        location = None

        if (
            data.latitude is not None
            and data.longitude is not None
        ):
            location = WKTElement(
                f"POINT({data.longitude} {data.latitude})",
                srid=4326,
            )

        place = Place(
            category_id=data.category_id,
            name=data.name,
            city=data.city,
            category_name=category_name,
            image_url=data.image_url,
            rating=data.rating,
            is_open=data.is_open,
            is_active=data.is_active,
            description=data.description,
            address=data.address,
            phone=data.phone,
            website=data.website,
            latitude=data.latitude,
            longitude=data.longitude,
            location=location,
            images=data.images,
            services=data.services,
            opening_time=data.opening_time,
            closing_time=data.closing_time,
        )

        return await self.repository.create_place(place)

    # ============================================================
    # Update
    # ============================================================

    async def update_place(
        self,
        place: Place,
        data: PlaceUpdate,
    ) -> Place:

        update_data = data.model_dump(
            exclude_unset=True
        )

        # --------------------------------------------------------
        # Category handling
        # --------------------------------------------------------

        if "category_id" in update_data:

            category_id = update_data["category_id"]

            if category_id is None:
                place.category_id = None

            else:
                category = await self.category_repository.get_category(
                    category_id
                )

                if category is None:
                    raise ValueError(
                        "Category not found"
                    )

                place.category_id = category_id

                # WAYN is Arabic-first — prefer the Arabic name when available.
                place.category_name = (
                    category.name_ar
                    or category.name_en
                )

            update_data.pop("category_id", None)

        # --------------------------------------------------------
        # Normal fields
        # --------------------------------------------------------

        for field, value in update_data.items():

            if field not in {
                "latitude",
                "longitude",
            }:
                setattr(
                    place,
                    field,
                    value,
                )

        # --------------------------------------------------------
        # Location
        # --------------------------------------------------------

        latitude = (
            data.latitude
            if "latitude" in update_data
            else place.latitude
        )

        longitude = (
            data.longitude
            if "longitude" in update_data
            else place.longitude
        )

        if (
            latitude is not None
            and longitude is not None
        ):
            place.latitude = latitude
            place.longitude = longitude

            place.location = WKTElement(
                f"POINT({longitude} {latitude})",
                srid=4326,
            )

        else:
            place.latitude = latitude
            place.longitude = longitude
            place.location = None

        return await self.repository.update_place(place)

    # ============================================================
    # Delete
    # ============================================================

    async def delete_place(
        self,
        place: Place,
    ) -> None:
        await self.repository.delete_place(place)