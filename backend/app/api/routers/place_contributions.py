from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_permission
from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.models.admin_user import AdminUser
from app.models.place_contribution import (
    PlaceContributionStatus,
    PlaceContributionType,
)
from app.models.user import User
from app.schemas.place_contribution import (
    PlaceContributionApproveRequest,
    PlaceContributionCreate,
    PlaceContributionListResponse,
    PlaceContributionRead,
    PlaceContributionRejectRequest,
)
from app.services.place_contribution_service import (
    PlaceContributionService,
)


router = APIRouter()


# ============================================================
# User: Create contribution
# ============================================================


@router.post(
    "/contributions",
    response_model=PlaceContributionRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_contribution(
    data: PlaceContributionCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> PlaceContributionRead:

    service = PlaceContributionService(session)

    try:
        contribution = await service.create_contribution(
            user_id=current_user.id,
            contribution_type=data.type,
            title=data.title,
            description=data.description,
            payload=data.payload,
            place_id=data.place_id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return contribution


# ============================================================
# User: List own contributions
# ============================================================


@router.get(
    "/contributions",
    response_model=PlaceContributionListResponse,
)
async def list_my_contributions(
    status_filter: PlaceContributionStatus | None = Query(
        default=None,
        alias="status",
    ),
    offset: int = Query(
        default=0,
        ge=0,
    ),
    limit: int = Query(
        default=20,
        ge=1,
        le=100,
    ),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> PlaceContributionListResponse:

    service = PlaceContributionService(session)

    items, total = await service.list_user_contributions(
        current_user.id,
        status=status_filter,
        offset=offset,
        limit=limit,
    )

    return PlaceContributionListResponse(
        items=items,
        total=total,
        offset=offset,
        limit=limit,
    )


# ============================================================
# User: Get own contribution
# ============================================================


@router.get(
    "/contributions/{contribution_id}",
    response_model=PlaceContributionRead,
)
async def get_my_contribution(
    contribution_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> PlaceContributionRead:

    service = PlaceContributionService(session)

    contribution = await service.get_contribution(
        contribution_id
    )

    if contribution is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contribution not found",
        )

    if contribution.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contribution not found",
        )

    return contribution


# ============================================================
# User: Cancel own contribution
# ============================================================


@router.post(
    "/contributions/{contribution_id}/cancel",
    response_model=PlaceContributionRead,
)
async def cancel_my_contribution(
    contribution_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> PlaceContributionRead:

    service = PlaceContributionService(session)

    contribution = await service.get_contribution(
        contribution_id
    )

    if contribution is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contribution not found",
        )

    if contribution.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contribution not found",
        )

    try:
        return await service.cancel_contribution(
            contribution=contribution,
            user_id=current_user.id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


# ============================================================
# Admin: List contributions
# ============================================================


@router.get(
    "/admin/contributions",
    response_model=PlaceContributionListResponse,
)
async def list_admin_contributions(
    status_filter: PlaceContributionStatus | None = Query(
        default=None,
        alias="status",
    ),
    contribution_type: PlaceContributionType | None = Query(
        default=None,
    ),
    offset: int = Query(
        default=0,
        ge=0,
    ),
    limit: int = Query(
        default=20,
        ge=1,
        le=100,
    ),
    admin_user: AdminUser = Depends(
        require_permission("contributions.read")
    ),
    session: AsyncSession = Depends(get_session),
) -> PlaceContributionListResponse:

    service = PlaceContributionService(session)

    items, total = await service.list_admin_contributions(
        status=status_filter,
        contribution_type=contribution_type,
        offset=offset,
        limit=limit,
    )

    return PlaceContributionListResponse(
        items=items,
        total=total,
        offset=offset,
        limit=limit,
    )


# ============================================================
# Admin: Approve contribution
# ============================================================


@router.post(
    "/admin/contributions/{contribution_id}/approve",
    response_model=PlaceContributionRead,
)
async def approve_contribution(
    contribution_id: UUID,
    data: PlaceContributionApproveRequest,
    admin_user: AdminUser = Depends(
        require_permission("contributions.approve")
    ),
    session: AsyncSession = Depends(get_session),
) -> PlaceContributionRead:

    service = PlaceContributionService(session)

    contribution = await service.get_contribution(
        contribution_id
    )

    if contribution is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contribution not found",
        )

    try:
        return await service.approve_contribution(
            contribution=contribution,
            admin_id=admin_user.id,
            points=data.points,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


# ============================================================
# Admin: Reject contribution
# ============================================================


@router.post(
    "/admin/contributions/{contribution_id}/reject",
    response_model=PlaceContributionRead,
)
async def reject_contribution(
    contribution_id: UUID,
    data: PlaceContributionRejectRequest,
    admin_user: AdminUser = Depends(
        require_permission("contributions.reject")
    ),
    session: AsyncSession = Depends(get_session),
) -> PlaceContributionRead:

    service = PlaceContributionService(session)

    contribution = await service.get_contribution(
        contribution_id
    )

    if contribution is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contribution not found",
        )

    try:
        return await service.reject_contribution(
            contribution=contribution,
            admin_id=admin_user.id,
            rejection_reason=data.rejection_reason,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc