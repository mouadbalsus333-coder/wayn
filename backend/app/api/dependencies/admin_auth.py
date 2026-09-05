from urllib.parse import urlparse

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_session
from app.core.config import settings
from app.core.security import decode_access_token
from app.models.admin_user import AdminUser
from app.models.role import Role


security = HTTPBearer(auto_error=False)


async def get_current_admin(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_session),
) -> AdminUser:

    cookie_token = request.cookies.get(settings.admin_cookie_name)
    using_cookie = credentials is None and bool(cookie_token)

    if credentials is None and not cookie_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials if credentials else cookie_token

    if using_cookie and request.method not in {
        "GET",
        "HEAD",
        "OPTIONS",
    }:
        _validate_cookie_request_origin(request)

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
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin session",
            headers={"WWW-Authenticate": "Bearer"},
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
            ),
            selectinload(AdminUser.direct_permissions),
        )
        .where(
            AdminUser.id == admin_id
        )
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

    token_version = payload.get("ver")

    if token_version != admin_user.token_version:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has been invalidated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return admin_user


def _validate_cookie_request_origin(request: Request) -> None:
    allowed_origins = set(settings.cors_origins)
    origin = request.headers.get("origin")

    if origin in allowed_origins:
        return

    referer = request.headers.get("referer")

    if referer:
        parsed = urlparse(referer)
        referer_origin = (
            f"{parsed.scheme}://{parsed.netloc}"
            if parsed.scheme and parsed.netloc
            else ""
        )

        if referer_origin in allowed_origins:
            return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Invalid request origin",
    )


def get_admin_permissions(
    admin_user: AdminUser,
) -> set[str]:
    permissions: set[str] = set()

    # ============================================================
    # Permissions inherited from active roles
    # ============================================================

    for role in admin_user.roles:
        if not role.is_active:
            continue

        for permission in role.permissions:
            permissions.add(permission.name)

    # ============================================================
    # Permissions assigned directly to this admin user
    # ============================================================

    for permission in admin_user.direct_permissions:
        permissions.add(permission.name)

    return permissions


def require_permission(permission_name: str):

    async def permission_checker(
        admin_user: AdminUser = Depends(get_current_admin),
    ) -> AdminUser:

        permissions = get_admin_permissions(
            admin_user
        )

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
            role.is_active
            and role.name == role_name
            for role in admin_user.roles
        )

        if not has_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have the required role",
            )

        return admin_user

    return role_checker