from sqlalchemy import delete, insert, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.admin_associations import (
    admin_user_permissions,
    admin_user_roles,
)
from app.models.admin_user import AdminUser
from app.models.permission import Permission
from app.models.role import Role


class AdminUserRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_email(
        self,
        email: str,
    ) -> AdminUser | None:
        result = await self.session.execute(
            select(AdminUser)
            .options(
                selectinload(AdminUser.roles).selectinload(
                    Role.permissions
                ),
                selectinload(AdminUser.direct_permissions),
            )
            .where(
                AdminUser.email == email
            )
        )

        return result.scalar_one_or_none()

    async def get_by_id(
        self,
        admin_id: int,
    ) -> AdminUser | None:
        result = await self.session.execute(
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

        return result.scalar_one_or_none()

    async def list_admin_users(self) -> list[AdminUser]:
        result = await self.session.execute(
            select(AdminUser)
            .options(
                selectinload(AdminUser.roles).selectinload(
                    Role.permissions
                ),
                selectinload(AdminUser.direct_permissions),
            )
            .order_by(AdminUser.id.asc())
        )

        return list(result.scalars().all())

    async def create_admin_user(
        self,
        admin_user: AdminUser,
    ) -> AdminUser:
        self.session.add(admin_user)

        await self.session.commit()

        await self.session.refresh(admin_user)

        return admin_user

    async def update_admin_user(
        self,
        admin_user: AdminUser,
    ) -> AdminUser:
        await self.session.commit()

        await self.session.refresh(admin_user)

        return admin_user

    async def delete_admin_user(
        self,
        admin_user_id: int,
    ) -> None:
        """Delete one AdminUser and its associations atomically.

        Role and direct-permission links are removed explicitly (the
        foreign keys also cascade, but doing it here keeps the delete
        deterministic on every backend). The regular ``users`` account
        is NOT touched — it lives in a separate table linked only by
        email.
        """
        await self.session.execute(
            delete(admin_user_roles).where(
                admin_user_roles.c.admin_user_id == admin_user_id
            )
        )

        await self.session.execute(
            delete(admin_user_permissions).where(
                admin_user_permissions.c.admin_user_id == admin_user_id
            )
        )

        await self.session.execute(
            delete(AdminUser).where(AdminUser.id == admin_user_id)
        )

        await self.session.commit()

    async def get_permission(
        self,
        permission_id: int,
    ) -> Permission | None:
        result = await self.session.execute(
            select(Permission).where(
                Permission.id == permission_id
            )
        )

        return result.scalar_one_or_none()

    async def add_permission_to_user(
        self,
        admin_user_id: int,
        permission_id: int,
    ) -> None:
        result = await self.session.execute(
            select(admin_user_permissions).where(
                admin_user_permissions.c.admin_user_id == admin_user_id,
                admin_user_permissions.c.permission_id == permission_id,
            )
        )

        if result.first() is None:
            await self.session.execute(
                insert(admin_user_permissions).values(
                    admin_user_id=admin_user_id,
                    permission_id=permission_id,
                )
            )

        await self.session.commit()

    async def replace_user_permissions(
        self,
        admin_user_id: int,
        permission_ids: list[int],
    ) -> None:
        await self.session.execute(
            delete(admin_user_permissions).where(
                admin_user_permissions.c.admin_user_id == admin_user_id
            )
        )

        if permission_ids:
            await self.session.execute(
                insert(admin_user_permissions),
                [
                    {
                        "admin_user_id": admin_user_id,
                        "permission_id": permission_id,
                    }
                    for permission_id in permission_ids
                ],
            )

        await self.session.commit()

    async def get_roles_for_user(
        self,
        admin_user_id: int,
    ) -> list[Role]:
        result = await self.session.execute(
            select(Role)
            .join(
                admin_user_roles,
                admin_user_roles.c.role_id == Role.id,
            )
            .where(
                admin_user_roles.c.admin_user_id == admin_user_id
            )
            .order_by(Role.name.asc())
        )

        return list(result.scalars().all())

    async def add_role_to_user(
        self,
        admin_user_id: int,
        role_id: int,
    ) -> None:
        result = await self.session.execute(
            select(admin_user_roles).where(
                admin_user_roles.c.admin_user_id == admin_user_id,
                admin_user_roles.c.role_id == role_id,
            )
        )

        if result.first() is None:
            await self.session.execute(
                insert(admin_user_roles).values(
                    admin_user_id=admin_user_id,
                    role_id=role_id,
                )
            )

        await self.session.commit()

    async def remove_role_from_user(
        self,
        admin_user_id: int,
        role_id: int,
    ) -> None:
        await self.session.execute(
            delete(admin_user_roles).where(
                admin_user_roles.c.admin_user_id == admin_user_id,
                admin_user_roles.c.role_id == role_id,
            )
        )

        await self.session.commit()

    async def replace_user_roles(
        self,
        admin_user_id: int,
        role_ids: list[int],
    ) -> None:
        await self.session.execute(
            delete(admin_user_roles).where(
                admin_user_roles.c.admin_user_id == admin_user_id
            )
        )

        if role_ids:
            await self.session.execute(
                insert(admin_user_roles),
                [
                    {
                        "admin_user_id": admin_user_id,
                        "role_id": role_id,
                    }
                    for role_id in role_ids
                ],
            )

        await self.session.commit()
