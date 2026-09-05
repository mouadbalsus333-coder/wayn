"""Resolve the admin context that belongs to a regular :class:`User`.

WAYN keeps two intentionally separate identity stores:

* :class:`~app.models.user.User` — the regular, user-facing account.
* :class:`~app.models.admin_user.AdminUser` — the administrative account.

They are linked by email. A user whose email matches an *active*
``AdminUser`` is an admin and should be able to reach the admin panel
without typing credentials a second time (single-sign-on from the normal
login). This module computes the small, read-only context that the regular
``/auth/me`` (and login) responses attach to :class:`UserRead.admin`.

Security:
    This module only *reports* admin context for UX (e.g. showing the
    ``لوحة الإدارة`` entry point). It is deliberately **not** an
    authorization boundary — every admin endpoint independently re-checks
    the admin token, the active status and the required permission via
    ``app.api.dependencies.admin_auth``.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies.admin_auth import get_admin_permissions
from app.models.admin_user import AdminUser
from app.models.role import Role
from app.schemas.user_auth import UserAdminInfo


async def get_user_admin_context(
    session: AsyncSession,
    user_email: str,
) -> UserAdminInfo | None:
    """Return the admin context for ``user_email`` or ``None``.

    ``None`` is returned when there is no AdminUser with that email. A
    disabled AdminUser still returns a context object so the client can
    distinguish "not an admin" from "admin but disabled" (and therefore
    hide the entry point).
    """

    if not user_email:
        return None

    result = await session.execute(
        select(AdminUser)
        .options(
            selectinload(AdminUser.roles).selectinload(
                Role.permissions
            ),
            selectinload(AdminUser.direct_permissions),
        )
        .where(AdminUser.email == user_email.lower())
    )

    admin = result.scalar_one_or_none()

    if admin is None:
        return None

    role_names = sorted(
        {
            role.name
            for role in admin.roles
            if role.is_active
        }
    )

    permissions = sorted(
        get_admin_permissions(admin)
    )

    primary_role = _primary_role(role_names)

    return UserAdminInfo(
        role=primary_role,
        # An admin account that is not active is "disabled".
        admin_status="active" if admin.is_active else "disabled",
        permissions=permissions,
    )


def _primary_role(role_names: list[str]) -> str | None:
    """Pick a single human-facing role label from the resolved roles."""

    if "super_admin" in role_names:
        return "super_admin"

    if "admin" in role_names:
        return "admin"

    return role_names[0] if role_names else None