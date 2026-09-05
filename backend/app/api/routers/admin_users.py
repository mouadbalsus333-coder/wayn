from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_role
from app.core.database import get_session
from app.repositories.admin_user_repository import AdminUserRepository
from app.repositories.role_repository import RoleRepository
from app.schemas.admin_user import (
    AdminUserCreate,
    AdminUserRead,
    AdminUserUpdate,
    AdminUserRoleUpdate,
)
from app.schemas.admin_user_permission import AdminUserPermissionRead
from app.schemas.role import RoleRead
from app.services.admin_user_service import AdminUserService


router = APIRouter(
    prefix="/admin/users",
    tags=["Admin Users"],
)


def _build_service(
    session: AsyncSession,
) -> AdminUserService:
    return AdminUserService(
        admin_user_repository=AdminUserRepository(session),
        role_repository=RoleRepository(session),
        session=session,
    )


# ============================================================
# Admin Users CRUD
# ============================================================


@router.get(
    "",
    response_model=list[AdminUserRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def list_admin_users(
    session: AsyncSession = Depends(get_session),
) -> list[AdminUserRead]:
    service = _build_service(session)

    return await service.list_admin_users()


@router.post(
    "",
    response_model=AdminUserRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def create_admin_user(
    data: AdminUserCreate,
    session: AsyncSession = Depends(get_session),
) -> AdminUserRead:
    service = _build_service(session)

    try:
        return await service.create_admin_user(data)
    except ValueError as exc:
        message = str(exc)

        if "already exists" in message:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=message,
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc


@router.get(
    "/{admin_user_id}",
    response_model=AdminUserRead,
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def get_admin_user(
    admin_user_id: int,
    session: AsyncSession = Depends(get_session),
) -> AdminUserRead:
    service = _build_service(session)

    admin_user = await service.get_admin_user(admin_user_id)

    if admin_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin user not found",
        )

    return admin_user


@router.put(
    "/{admin_user_id}",
    response_model=AdminUserRead,
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def update_admin_user(
    admin_user_id: int,
    data: AdminUserUpdate,
    session: AsyncSession = Depends(get_session),
) -> AdminUserRead:
    service = _build_service(session)

    admin_user = await service.update_admin_user(
        admin_user_id,
        data,
    )

    if admin_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin user not found",
        )

    return admin_user


@router.patch(
    "/{admin_user_id}/activate",
    response_model=AdminUserRead,
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def activate_admin_user(
    admin_user_id: int,
    session: AsyncSession = Depends(get_session),
) -> AdminUserRead:
    service = _build_service(session)

    admin_user = await service.activate_admin_user(admin_user_id)

    if admin_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin user not found",
        )

    return admin_user


@router.patch(
    "/{admin_user_id}/deactivate",
    response_model=AdminUserRead,
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def deactivate_admin_user(
    admin_user_id: int,
    session: AsyncSession = Depends(get_session),
) -> AdminUserRead:
    service = _build_service(session)

    try:
        admin_user = await service.deactivate_admin_user(admin_user_id)
    except ValueError as exc:
        message = str(exc)
        if "Admin user not found" in message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message,
            ) from exc
        if "Super Admin cannot be deactivated" in message:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=message,
            ) from exc
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc

    return admin_user


@router.delete(
    "/{admin_user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def delete_admin_user(
    admin_user_id: int,
    session: AsyncSession = Depends(get_session),
) -> None:
    """Remove the administrative account only.

    The regular ``users`` account linked by email is intentionally
    kept: deleting an admin must never destroy the user's normal
    WAYN account. Role and direct-permission associations are
    removed with the AdminUser row in a single transaction.
    """
    service = _build_service(session)

    try:
        await service.delete_admin_user(admin_user_id)
    except ValueError as exc:
        message = str(exc)

        if "Admin user not found" in message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message,
            ) from exc

        if "Super Admin cannot be deleted" in message:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=message,
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc


# ============================================================
# Admin User Roles
# ============================================================


@router.get(
    "/{admin_user_id}/roles",
    response_model=list[RoleRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def get_admin_user_roles(
    admin_user_id: int,
    session: AsyncSession = Depends(get_session),
) -> list[RoleRead]:
    service = _build_service(session)

    try:
        return await service.list_roles_for_user(admin_user_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc


@router.put(
    "/{admin_user_id}/roles",
    response_model=list[RoleRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def replace_admin_user_roles(
    admin_user_id: int,
    data: AdminUserRoleUpdate,
    session: AsyncSession = Depends(get_session),
) -> list[RoleRead]:
    service = _build_service(session)

    try:
        return await service.replace_user_roles(
            admin_user_id,
            data.role_ids,
        )
    except ValueError as exc:
        message = str(exc)

        if "Admin user not found" in message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message,
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc


@router.post(
    "/{admin_user_id}/roles/{role_id}",
    response_model=list[RoleRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def add_admin_user_role(
    admin_user_id: int,
    role_id: int,
    session: AsyncSession = Depends(get_session),
) -> list[RoleRead]:
    service = _build_service(session)

    try:
        return await service.add_role_to_user(
            admin_user_id,
            role_id,
        )
    except ValueError as exc:
        message = str(exc)

        if "Admin user not found" in message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message,
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc


@router.delete(
    "/{admin_user_id}/roles/{role_id}",
    response_model=list[RoleRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def remove_admin_user_role(
    admin_user_id: int,
    role_id: int,
    session: AsyncSession = Depends(get_session),
) -> list[RoleRead]:
    service = _build_service(session)

    try:
        return await service.remove_role_from_user(
            admin_user_id,
            role_id,
        )
    except ValueError as exc:
        message = str(exc)

        if "Admin user not found" in message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message,
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc


# ============================================================
# Resolved Permissions
# ============================================================


@router.get(
    "/{admin_user_id}/resolved-permissions",
    response_model=list[AdminUserPermissionRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def get_resolved_permissions(
    admin_user_id: int,
    session: AsyncSession = Depends(get_session),
) -> list[AdminUserPermissionRead]:
    service = _build_service(session)

    try:
        permissions = await service.get_resolved_permissions(
            admin_user_id
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc

    return [
        AdminUserPermissionRead(
            id=permission.id,
            name=permission.name,
            description=permission.description,
        )
        for permission in permissions
    ]
