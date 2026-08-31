import asyncio
import getpass

from sqlalchemy import insert, select

from app.core.database import AsyncSessionLocal
from app.core.security import hash_password
from app.models.admin_associations import (
    admin_user_roles,
    role_permissions,
)
from app.models.admin_user import AdminUser
from app.models.permission import Permission
from app.models.role import Role


PERMISSIONS = [
    ("users.read", "View users"),
    ("users.write", "Create and update users"),
    ("users.delete", "Delete users"),
    ("places.read", "View places"),
    ("places.write", "Create and update places"),
    ("places.delete", "Delete places"),
    ("categories.read", "View categories"),
    ("categories.write", "Create and update categories"),
    ("reports.read", "View reports"),
    ("reports.write", "Handle reports"),

    # Place contributions
    ("contributions.read", "View place contributions"),
    ("contributions.approve", "Approve place contributions"),
    ("contributions.reject", "Reject place contributions"),
]


ROLES = [
    (
        "super_admin",
        "Full access to the WAYN administration system",
    ),
    (
        "admin",
        "Administrative access",
    ),
    (
        "moderator",
        "Moderation access",
    ),
    (
        "editor",
        "Content editing access",
    ),
]


ROLE_PERMISSIONS = {
    "super_admin": [
        "users.read",
        "users.write",
        "users.delete",
        "places.read",
        "places.write",
        "places.delete",
        "categories.read",
        "categories.write",
        "reports.read",
        "reports.write",

        # Place contributions
        "contributions.read",
        "contributions.approve",
        "contributions.reject",
    ],

    "admin": [
        "users.read",
        "users.write",
        "places.read",
        "places.write",
        "categories.read",
        "categories.write",
        "reports.read",
        "reports.write",

        # Place contributions
        "contributions.read",
        "contributions.approve",
        "contributions.reject",
    ],

    "moderator": [
        "users.read",
        "places.read",
        "reports.read",
        "reports.write",

        # Place contributions
        "contributions.read",
        "contributions.approve",
        "contributions.reject",
    ],

    "editor": [
        "places.read",
        "places.write",
        "categories.read",
        "categories.write",
    ],
}


async def get_or_create_permission(
    session,
    name: str,
    description: str,
) -> Permission:
    result = await session.execute(
        select(Permission).where(
            Permission.name == name
        )
    )

    permission = result.scalar_one_or_none()

    if permission is None:
        permission = Permission(
            name=name,
            description=description,
        )

        session.add(permission)
        await session.flush()

    return permission


async def get_or_create_role(
    session,
    name: str,
    description: str,
) -> Role:
    result = await session.execute(
        select(Role).where(
            Role.name == name
        )
    )

    role = result.scalar_one_or_none()

    if role is None:
        role = Role(
            name=name,
            description=description,
            is_active=True,
        )

        session.add(role)
        await session.flush()

    return role


async def ensure_role_permission(
    session,
    role: Role,
    permission: Permission,
) -> None:
    result = await session.execute(
        select(role_permissions).where(
            role_permissions.c.role_id == role.id,
            role_permissions.c.permission_id == permission.id,
        )
    )

    existing = result.first()

    if existing is None:
        await session.execute(
            insert(role_permissions).values(
                role_id=role.id,
                permission_id=permission.id,
            )
        )


async def ensure_admin_role(
    session,
    admin_user: AdminUser,
    role: Role,
) -> None:
    result = await session.execute(
        select(admin_user_roles).where(
            admin_user_roles.c.admin_user_id == admin_user.id,
            admin_user_roles.c.role_id == role.id,
        )
    )

    existing = result.first()

    if existing is None:
        await session.execute(
            insert(admin_user_roles).values(
                admin_user_id=admin_user.id,
                role_id=role.id,
            )
        )


async def create_admin() -> None:
    print()
    print("WAYN Admin Seeder")
    print("-----------------")
    print()

    email = input("Admin email: ").strip().lower()
    full_name = input("Admin full name: ").strip()

    password = getpass.getpass("Admin password: ")
    password_confirm = getpass.getpass(
        "Confirm password: "
    )

    if not email:
        raise ValueError("Email is required.")

    if not full_name:
        raise ValueError("Full name is required.")

    if not password:
        raise ValueError("Password is required.")

    if password != password_confirm:
        raise ValueError("Passwords do not match.")

    async with AsyncSessionLocal() as session:
        try:
            # =====================================================
            # 1. Create / load permissions
            # =====================================================

            permissions = {}

            for name, description in PERMISSIONS:
                permissions[name] = (
                    await get_or_create_permission(
                        session=session,
                        name=name,
                        description=description,
                    )
                )

            # =====================================================
            # 2. Create / load roles
            # =====================================================

            roles = {}

            for name, description in ROLES:
                roles[name] = await get_or_create_role(
                    session=session,
                    name=name,
                    description=description,
                )

            # =====================================================
            # 3. Configure role permissions
            #
            # We intentionally use the association table directly
            # instead of accessing role.permissions.
            #
            # This prevents MissingGreenlet errors with AsyncSession.
            # =====================================================

            for role_name, permission_names in ROLE_PERMISSIONS.items():
                role = roles[role_name]

                for permission_name in permission_names:
                    permission = permissions[permission_name]

                    await ensure_role_permission(
                        session=session,
                        role=role,
                        permission=permission,
                    )

            # =====================================================
            # 4. Find existing admin user
            # =====================================================

            result = await session.execute(
                select(AdminUser).where(
                    AdminUser.email == email
                )
            )

            admin_user = result.scalar_one_or_none()

            # =====================================================
            # 5. Create or update admin user
            # =====================================================

            if admin_user is None:
                admin_user = AdminUser(
                    email=email,
                    password_hash=hash_password(password),
                    full_name=full_name,
                    is_active=True,
                )

                session.add(admin_user)

                # We need the generated ID before inserting
                # into admin_user_roles.
                await session.flush()

                print()
                print("Admin user created.")

            else:
                admin_user.password_hash = hash_password(
                    password
                )
                admin_user.full_name = full_name
                admin_user.is_active = True

                await session.flush()

                print()
                print("Admin user already exists.")
                print("Admin user updated.")

            # =====================================================
            # 6. Assign super_admin role
            #
            # Again, use association table directly.
            # =====================================================

            super_admin = roles["super_admin"]

            await ensure_admin_role(
                session=session,
                admin_user=admin_user,
                role=super_admin,
            )

            # =====================================================
            # 7. Commit everything
            # =====================================================

            await session.commit()

            # =====================================================
            # 8. Success
            # =====================================================

            print()
            print("===================================")
            print("WAYN Admin initialization complete")
            print("===================================")
            print(f"Email: {email}")
            print("Role: super_admin")
            print("Permissions: all")
            print("===================================")
            print()

        except Exception:
            await session.rollback()
            raise


if __name__ == "__main__":
    asyncio.run(create_admin())