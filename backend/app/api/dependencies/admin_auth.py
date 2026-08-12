from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_session
from app.core.security import decode_access_token
from app.models.admin_user import AdminUser
from app.models.role import Role


security = HTTPBearer(auto_error=False)


async def get_current_admin(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_session),
) -> AdminUser:

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials

    try:
        payload = decode_access_token(token)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    if payload.get("type") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin token required",
        )

    subject = payload.get("sub")

    if not subject:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        admin_id = int(subject)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    result = await session.execute(
        select(AdminUser)
        .options(
            selectinload(AdminUser.roles).selectinload(
                Role.permissions
            )
        )
        .where(AdminUser.id == admin_id)
    )

    admin_user = result.scalar_one_or_none()

    if admin_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin account not found",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not admin_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin account is inactive",
        )

    return admin_user


def get_admin_permissions(admin_user: AdminUser) -> set[str]:
    return {
        permission.name
        for role in admin_user.roles
        if role.is_active
        for permission in role.permissions
    }


def require_permission(permission_name: str):

    async def permission_checker(
        admin_user: AdminUser = Depends(get_current_admin),
    ) -> AdminUser:

        permissions = get_admin_permissions(admin_user)

        if permission_name not in permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to perform this action",
            )

        return admin_user

    return permission_checker


def require_role(role_name: str):

    async def role_checker(
        admin_user: AdminUser = Depends(get_current_admin),
    ) -> AdminUser:

        has_role = any(
            role.is_active and role.name == role_name
            for role in admin_user.roles
        )

        if not has_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have the required role",
            )

        return admin_user

    return role_checker
