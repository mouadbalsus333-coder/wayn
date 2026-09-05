from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import (
    get_current_admin,
    get_admin_permissions,
    require_permission,
)
from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.core.security import (
    create_access_token,
    verify_password,
)
from app.models.admin_user import AdminUser
from app.models.user import User
from app.repositories.admin_user_repository import AdminUserRepository
from app.schemas.admin_auth import (
    AdminLoginRequest,
    AdminLoginResponse,
    AdminSessionRequest,
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

    roles = sorted(
        {
            role.name
            for role in admin_user.roles
            if role.is_active
        }
    )

    permissions = sorted(
        get_admin_permissions(admin_user)
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


# ============================================================
# Admin single-sign-on (from a normal user session)
# ============================================================
#
# When a regular user is also an admin (their email matches an active
# AdminUser), the Flutter app calls this endpoint with the *user* bearer
# token to obtain an *admin* token without asking for credentials again.
# The returned admin token is scoped exactly like the one issued by
# /admin/auth/login, so the rest of the admin surface works unchanged.


@router.post(
    "/session",
    response_model=AdminLoginResponse,
)
async def create_admin_session(
    data: AdminSessionRequest | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> AdminLoginResponse:

    repository = AdminUserRepository(session)

    admin_user = await repository.get_by_email(
        current_user.email.lower()
    )

    if admin_user is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account does not have administrative access",
        )

    if not admin_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin account is inactive",
        )

    roles = sorted(
        {
            role.name
            for role in admin_user.roles
            if role.is_active
        }
    )

    permissions = sorted(
        get_admin_permissions(admin_user)
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
        "roles": sorted(
            {
                role.name
                for role in admin_user.roles
                if role.is_active
            }
        ),
        "permissions": sorted(
            get_admin_permissions(admin_user)
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