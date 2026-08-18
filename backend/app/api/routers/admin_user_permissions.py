from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_role
from app.core.database import get_session
from app.repositories.admin_user_permission_repository import (
    AdminUserPermissionRepository,
)
from app.schemas.admin_user_permission import (
    AdminUserPermissionRead,
    AdminUserPermissionUpdate,
)
from app.services.admin_user_permission_service import (
    AdminUserPermissionService,
)


router = APIRouter(
    prefix="/admin/users",
    tags=["Admin User Permissions"],
)


@router.get(
    "/{admin_user_id}/permissions",
    response_model=list[AdminUserPermissionRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def get_admin_user_permissions(
    admin_user_id: int,
    session: AsyncSession = Depends(get_session),
) -> list[AdminUserPermissionRead]:

    repository = AdminUserPermissionRepository(session)
    service = AdminUserPermissionService(repository)

    try:
        permissions = await service.get_user_permissions(
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


@router.put(
    "/{admin_user_id}/permissions",
    response_model=list[AdminUserPermissionRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def replace_admin_user_permissions(
    admin_user_id: int,
    data: AdminUserPermissionUpdate,
    session: AsyncSession = Depends(get_session),
) -> list[AdminUserPermissionRead]:

    repository = AdminUserPermissionRepository(session)
    service = AdminUserPermissionService(repository)

    try:
        permissions = await service.replace_user_permissions(
            admin_user_id=admin_user_id,
            permission_ids=data.permission_ids,
        )
    except ValueError as exc:
        if str(exc) == "Admin user not found":
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=str(exc),
            ) from exc

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


@router.post(
    "/{admin_user_id}/permissions/{permission_id}",
    response_model=list[AdminUserPermissionRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def add_admin_user_permission(
    admin_user_id: int,
    permission_id: int,
    session: AsyncSession = Depends(get_session),
) -> list[AdminUserPermissionRead]:

    repository = AdminUserPermissionRepository(session)
    service = AdminUserPermissionService(repository)

    try:
        permissions = await service.add_permission(
            admin_user_id=admin_user_id,
            permission_id=permission_id,
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


@router.delete(
    "/{admin_user_id}/permissions/{permission_id}",
    response_model=list[AdminUserPermissionRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def remove_admin_user_permission(
    admin_user_id: int,
    permission_id: int,
    session: AsyncSession = Depends(get_session),
) -> list[AdminUserPermissionRead]:

    repository = AdminUserPermissionRepository(session)
    service = AdminUserPermissionService(repository)

    try:
        permissions = await service.remove_permission(
            admin_user_id=admin_user_id,
            permission_id=permission_id,
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