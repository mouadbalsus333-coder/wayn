import math
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import (
    get_admin_permissions,
    get_current_admin,
)
from app.core.database import get_session
from app.models.user import AccountStatus
from app.repositories.user.repository import UserRepository
from app.schemas.admin_regular_user import (
    AdminRegularUserRead,
    AdminRegularUserStatusUpdate,
)
from app.schemas.pagination import PaginatedResponse
from app.services.user.service import UserService


router = APIRouter(
    prefix="/admin/regular-users",
    tags=["Admin Regular Users"],
)


def _service(session: AsyncSession) -> UserService:
    return UserService(session)


def _require_permission(admin_user, permission: str) -> None:
    if permission not in get_admin_permissions(admin_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action",
        )


@router.get(
    "",
    response_model=PaginatedResponse[AdminRegularUserRead],
)
async def list_regular_users(
    response: Response,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    search: str | None = Query(default=None, max_length=255),
    account_status: AccountStatus | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    is_verified: bool | None = Query(default=None),
    sort_by: Literal[
        "created_at",
        "updated_at",
        "full_name",
        "username",
        "last_login_at",
        "points",
    ] = Query(default="created_at"),
    sort_order: Literal["asc", "desc"] = Query(default="desc"),
    admin_user=Depends(get_current_admin),
    session: AsyncSession = Depends(get_session),
) -> PaginatedResponse[AdminRegularUserRead]:
    _require_permission(admin_user, "users.read")
    items, total = await _service(session).list_admin_users(
        offset=(page - 1) * limit,
        limit=limit,
        search=search,
        account_status=account_status,
        is_active=is_active,
        is_verified=is_verified,
        sort_by=sort_by,
        sort_order=sort_order,
    )
    pages = math.ceil(total / limit) if total else 0
    response.headers["X-Total-Count"] = str(total)
    return PaginatedResponse[AdminRegularUserRead](
        items=items,
        total=total,
        page=page,
        limit=limit,
        pages=pages,
    )


@router.get(
    "/{user_id}",
    response_model=AdminRegularUserRead,
)
async def get_regular_user(
    user_id: UUID,
    admin_user=Depends(get_current_admin),
    session: AsyncSession = Depends(get_session),
) -> AdminRegularUserRead:
    _require_permission(admin_user, "users.read")
    user = await _service(session).get_admin_user(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return user


@router.patch(
    "/{user_id}/status",
    response_model=AdminRegularUserRead,
)
async def update_regular_user_status(
    user_id: UUID,
    data: AdminRegularUserStatusUpdate,
    admin_user=Depends(get_current_admin),
    session: AsyncSession = Depends(get_session),
) -> AdminRegularUserRead:
    if data.account_status is None and data.is_active is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one status field is required",
        )

    restricted = (
        data.is_active is False
        or data.account_status in {
            AccountStatus.HIDDEN,
            AccountStatus.SUSPENDED,
            AccountStatus.BANNED,
        }
    )
    _require_permission(
        admin_user,
        "users.disable" if restricted else "users.update",
    )

    user = await UserRepository(session).get_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return await _service(session).update_admin_user_status(
        user,
        account_status=data.account_status,
        is_active=data.is_active,
        reason=data.status_reason,
        changed_by=admin_user.id,
        suspended_until=data.suspended_until,
    )