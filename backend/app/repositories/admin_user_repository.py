from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.admin_user import AdminUser
from app.models.role import Role


class AdminUserRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_email(self, email: str) -> AdminUser | None:
        result = await self.session.execute(
            select(AdminUser)
            .options(
                selectinload(AdminUser.roles).selectinload(
                    Role.permissions
                )
            )
            .where(AdminUser.email == email)
        )

        return result.scalar_one_or_none()

    async def get_by_id(self, admin_id: int) -> AdminUser | None:
        result = await self.session.execute(
            select(AdminUser)
            .options(
                selectinload(AdminUser.roles).selectinload(
                    Role.permissions
                )
            )
            .where(AdminUser.id == admin_id)
        )

        return result.scalar_one_or_none()