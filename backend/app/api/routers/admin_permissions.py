from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_role
from app.core.database import get_session
from app.repositories.permission_repository import PermissionRepository
from app.schemas.permission import (
    PermissionCreate,
    PermissionRead,
    PermissionUpdate,
)
from app.services.permission_service import PermissionService


router = APIRouter(
    prefix="/admin/permissions",
    tags=["Admin Permissions"],
)


@router.get(
    "",
    response_model=list[PermissionRead],
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def list_permissions(
    session: AsyncSession = Depends(get_session),
) -> list[PermissionRead]:
    repository = PermissionRepository(session)
    service = PermissionService(repository)

    return await service.get_permissions()


@router.get(
    "/{permission_id}",
    response_model=PermissionRead,
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def get_permission(
    permission_id: int,
    session: AsyncSession = Depends(get_session),
) -> PermissionRead:
    repository = PermissionRepository(session)
    service = PermissionService(repository)

    permission = await service.get_permission(
        permission_id
    )

    if permission is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Permission not found",
        )

    return permission


@router.post(
    "",
    response_model=PermissionRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def create_permission(
    data: PermissionCreate,
    session: AsyncSession = Depends(get_session),
) -> PermissionRead:
    repository = PermissionRepository(session)
    service = PermissionService(repository)

    try:
        return await service.create_permission(data)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc


@router.put(
    "/{permission_id}",
    response_model=PermissionRead,
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def update_permission(
    permission_id: int,
    data: PermissionUpdate,
    session: AsyncSession = Depends(get_session),
) -> PermissionRead:
    repository = PermissionRepository(session)
    service = PermissionService(repository)

    permission = await service.get_permission(
        permission_id
    )

    if permission is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Permission not found",
        )

    try:
        return await service.update_permission(
            permission,
            data,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc


@router.delete(
    "/{permission_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[
        Depends(require_role("super_admin")),
    ],
)
async def delete_permission(
    permission_id: int,
    session: AsyncSession = Depends(get_session),
) -> None:
    repository = PermissionRepository(session)
    service = PermissionService(repository)

    permission = await service.get_permission(
        permission_id
    )

    if permission is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Permission not found",
        )

    await service.delete_permission(permission)
