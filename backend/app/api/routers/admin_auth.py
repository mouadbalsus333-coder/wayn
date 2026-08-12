from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import (
    get_current_admin,
    require_permission,
)
from app.core.database import get_session
from app.core.security import (
    create_access_token,
    verify_password,
)
from app.models.admin_user import AdminUser
from app.repositories.admin_user_repository import AdminUserRepository
from app.schemas.admin_auth import (
    AdminLoginRequest,
    AdminLoginResponse,
)


router = APIRouter(
    prefix="/admin/auth",
    tags=["Admin Authentication"],
)


@router.post(
    "/login",
    response_model=AdminLoginResponse,
)
async def admin_login(
    data: AdminLoginRequest,
    session: AsyncSession = Depends(get_session),
) -> AdminLoginResponse:

    repository = AdminUserRepository(session)

    admin_user = await repository.get_by_email(
        data.email.lower()
    )

    if admin_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not admin_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin account is inactive",
        )

    if not verify_password(
        data.password,
        admin_user.password_hash,
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    roles = [
        role.name
        for role in admin_user.roles
        if role.is_active
    ]

    permissions = sorted(
        {
            permission.name
            for role in admin_user.roles
            if role.is_active
            for permission in role.permissions
        }
    )

    access_token = create_access_token(
        subject=str(admin_user.id),
        token_type="admin",
    )

    return AdminLoginResponse(
        access_token=access_token,
        token_type="bearer",
        admin_id=admin_user.id,
        email=admin_user.email,
        full_name=admin_user.full_name,
        roles=roles,
        permissions=permissions,
    )


@router.get("/me")
async def admin_me(
    admin_user: AdminUser = Depends(get_current_admin),
):
    return {
        "admin_id": admin_user.id,
        "email": admin_user.email,
        "full_name": admin_user.full_name,
        "roles": [
            role.name
            for role in admin_user.roles
            if role.is_active
        ],
        "permissions": sorted(
            {
                permission.name
                for role in admin_user.roles
                if role.is_active
                for permission in role.permissions
            }
        ),
    }


@router.get(
    "/test-permission",
    dependencies=[
        Depends(require_permission("places.write"))
    ],
)
async def test_permission():
    return {
        "message": "Permission Guard: OK",
        "permission": "places.write",
    }
