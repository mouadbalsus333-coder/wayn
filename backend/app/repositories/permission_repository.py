from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.permission import Permission


class PermissionRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def list_permissions(self) -> list[Permission]:
        result = await self.session.execute(
            select(Permission).order_by(Permission.name)
        )

        return result.scalars().all()

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

    async def get_by_name(
        self,
        name: str,
    ) -> Permission | None:
        result = await self.session.execute(
            select(Permission).where(
                Permission.name == name
            )
        )

        return result.scalar_one_or_none()

    async def create_permission(
        self,
        permission: Permission,
    ) -> Permission:
        self.session.add(permission)

        await self.session.commit()

        await self.session.refresh(permission)

        return permission

    async def update_permission(
        self,
        permission: Permission,
    ) -> Permission:
        await self.session.commit()

        await self.session.refresh(permission)

        return permission

    async def delete_permission(
        self,
        permission: Permission,
    ) -> None:
        await self.session.delete(permission)

        await self.session.commit()
