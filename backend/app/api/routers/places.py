import math
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.repositories.category_repository import CategoryRepository
from app.repositories.place_repository import PlaceRepository
from app.schemas.pagination import PaginatedResponse
from app.schemas.place import PlaceRead
from app.services.place_service import PlaceService


router = APIRouter()


# ============================================================
# Pagination helpers
# ============================================================


def _build_paginated_response(
    response: Response,
    *,
    items: list[PlaceRead],
    total: int,
    page: int,
    limit: int,
) -> PaginatedResponse[PlaceRead]:
    """Build a unified PaginatedResponse and attach pagination headers.

    The response body is a PaginatedResponse object with:
      - items: the list of items for the current page
      - total: total number of items matching the query
      - page: current page number (1-based)
      - limit: number of items per page
      - pages: total number of pages (ceil(total / limit))
    """
    pages = math.ceil(total / limit) if limit > 0 else 0

    response.headers["X-Total-Count"] = str(total)
    response.headers["X-Page"] = str(page)
    response.headers["X-Limit"] = str(limit)
    response.headers["X-Pages"] = str(pages)

    return PaginatedResponse[PlaceRead](
        items=items,
        total=total,
        page=page,
        limit=limit,
        pages=pages,
    )


# ============================================================
# Public Places
# ============================================================


@router.get(
    "/places",
    response_model=PaginatedResponse[PlaceRead],
)
async def list_places(
    response: Response,
    page: int = Query(
        1,
        ge=1,
        description="Page number",
    ),
    limit: int = Query(
        20,
        ge=1,
        le=100,
        description="Number of places per page",
    ),
    session: AsyncSession = Depends(get_session),
):
    repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        repository,
        category_repository,
    )

    offset = (page - 1) * limit

    places, total = await service.get_places(
        offset=offset,
        limit=limit,
    )

    return _build_paginated_response(
        response,
        items=places,
        total=total,
        page=page,
        limit=limit,
    )


# ============================================================
# IMPORTANT:
# Static routes must come before /places/{place_id}
# so "search", "open", "top-rated", "nearby", etc.
# are not treated as place IDs.
# ============================================================


@router.get(
    "/places/search",
    response_model=PaginatedResponse[PlaceRead],
)
async def search_places(
    response: Response,
    q: str = Query(
        "",
        alias="q",
    ),
    page: int = Query(
        1,
        ge=1,
    ),
    limit: int = Query(
        20,
        ge=1,
        le=100,
    ),
    session: AsyncSession = Depends(get_session),
):
    repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        repository,
        category_repository,
    )

    offset = (page - 1) * limit

    places, total = await service.search_places(
        q,
        offset=offset,
        limit=limit,
    )

    return _build_paginated_response(
        response,
        items=places,
        total=total,
        page=page,
        limit=limit,
    )


@router.get(
    "/places/open",
    response_model=PaginatedResponse[PlaceRead],
)
async def list_open_places(
    response: Response,
    page: int = Query(
        1,
        ge=1,
    ),
    limit: int = Query(
        20,
        ge=1,
        le=100,
    ),
    session: AsyncSession = Depends(get_session),
):
    repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        repository,
        category_repository,
    )

    offset = (page - 1) * limit

    places, total = await service.get_open_places(
        offset=offset,
        limit=limit,
    )

    return _build_paginated_response(
        response,
        items=places,
        total=total,
        page=page,
        limit=limit,
    )


@router.get(
    "/places/top-rated",
    response_model=PaginatedResponse[PlaceRead],
)
async def list_top_rated_places(
    response: Response,
    page: int = Query(
        1,
        ge=1,
    ),
    limit: int = Query(
        20,
        ge=1,
        le=100,
    ),
    session: AsyncSession = Depends(get_session),
):
    repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        repository,
        category_repository,
    )

    offset = (page - 1) * limit

    places, total = await service.get_highest_rated_places(
        offset=offset,
        limit=limit,
    )

    return _build_paginated_response(
        response,
        items=places,
        total=total,
        page=page,
        limit=limit,
    )


@router.get(
    "/places/most-visited",
    response_model=PaginatedResponse[PlaceRead],
)
async def list_most_visited_places(
    response: Response,
    page: int = Query(
        1,
        ge=1,
    ),
    limit: int = Query(
        20,
        ge=1,
        le=100,
    ),
    session: AsyncSession = Depends(get_session),
):
    repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        repository,
        category_repository,
    )

    offset = (page - 1) * limit

    places, total = await service.get_most_visited_places(
        offset=offset,
        limit=limit,
    )

    return _build_paginated_response(
        response,
        items=places,
        total=total,
        page=page,
        limit=limit,
    )


@router.get(
    "/places/nearby",
    response_model=PaginatedResponse[PlaceRead],
)
async def list_nearby_places(
    response: Response,
    latitude: float = Query(
        ...,
        ge=-90,
        le=90,
        description="User latitude",
    ),
    longitude: float = Query(
        ...,
        ge=-180,
        le=180,
        description="User longitude",
    ),
    radius: float = Query(
        5000,
        gt=0,
        le=100000,
        description="Search radius in meters",
    ),
    page: int = Query(
        1,
        ge=1,
    ),
    limit: int = Query(
        20,
        ge=1,
        le=100,
    ),
    session: AsyncSession = Depends(get_session),
):
    repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        repository,
        category_repository,
    )

    offset = (page - 1) * limit

    places, total = await service.get_nearby_places(
        latitude=latitude,
        longitude=longitude,
        radius_meters=radius,
        offset=offset,
        limit=limit,
    )

    return _build_paginated_response(
        response,
        items=places,
        total=total,
        page=page,
        limit=limit,
    )


@router.get(
    "/places/city/{city}",
    response_model=PaginatedResponse[PlaceRead],
)
async def list_places_by_city(
    response: Response,
    city: str,
    page: int = Query(
        1,
        ge=1,
    ),
    limit: int = Query(
        20,
        ge=1,
        le=100,
    ),
    session: AsyncSession = Depends(get_session),
):
    repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        repository,
        category_repository,
    )

    offset = (page - 1) * limit

    places, total = await service.get_places_by_city(
        city,
        offset=offset,
        limit=limit,
    )

    return _build_paginated_response(
        response,
        items=places,
        total=total,
        page=page,
        limit=limit,
    )


@router.get(
    "/places/category/{category_id}",
    response_model=PaginatedResponse[PlaceRead],
)
async def list_places_by_category(
    response: Response,
    category_id: str,
    page: int = Query(
        1,
        ge=1,
    ),
    limit: int = Query(
        20,
        ge=1,
        le=100,
    ),
    session: AsyncSession = Depends(get_session),
):
    repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        repository,
        category_repository,
    )

    offset = (page - 1) * limit

    places, total = await service.get_places_by_category(
        category_id,
        offset=offset,
        limit=limit,
    )

    return _build_paginated_response(
        response,
        items=places,
        total=total,
        page=page,
        limit=limit,
    )


# ============================================================
# Dynamic UUID route comes AFTER all static routes.
# ============================================================


@router.get(
    "/places/{place_id}",
    response_model=PlaceRead,
)
async def get_place(
    place_id: str,
    session: AsyncSession = Depends(get_session),
):
    # Validate UUID format to avoid DB errors for non-UUID strings.
    try:
        UUID(place_id)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=404,
            detail="Place not found",
        )

    repository = PlaceRepository(session)
    category_repository = CategoryRepository(session)

    service = PlaceService(
        repository,
        category_repository,
    )

    place = await service.get_place_by_id(
        place_id
    )

    if place is None:
        raise HTTPException(
            status_code=404,
            detail="Place not found",
        )

    return place