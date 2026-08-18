from sqlalchemy import delete, insert, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.admin_associations import admin_user_roles
from app.models.admin_user import AdminUser
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
