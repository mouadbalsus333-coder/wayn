from sqlalchemy import delete, insert, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.admin_associations import admin_user_permissions
from app.models.admin_user import AdminUser
from app.models.permission import Permission
from app.models.role import Role


class AdminUserPermissionRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_admin_user(
        self,
        admin_user_id: int,
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
                AdminUser.id == admin_user_id
            )
        )

        return result.scalar_one_or_none()

    async def list_permissions_for_user(
        self,
        admin_user_id: int,
    ) -> list[Permission]:
        result = await self.session.execute(
            select(Permission)
            .join(
                admin_user_permissions,
                admin_user_permissions.c.permission_id
                == Permission.id,
            )
            .where(
                admin_user_permissions.c.admin_user_id
                == admin_user_id
            )
            .order_by(Permission.name.asc())
        )

        return list(result.scalars().all())

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
                admin_user_permissions.c.admin_user_id
                == admin_user_id,
                admin_user_permissions.c.permission_id
                == permission_id,
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

    async def remove_permission_from_user(
        self,
        admin_user_id: int,
        permission_id: int,
    ) -> None:
        await self.session.execute(
            delete(admin_user_permissions).where(
                admin_user_permissions.c.admin_user_id
                == admin_user_id,
                admin_user_permissions.c.permission_id
                == permission_id,
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
                admin_user_permissions.c.admin_user_id
                == admin_user_id
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