from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.place_social import PlaceSocial, PlaceSocialType


class PlaceSocialRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def list_for_place(
        self,
        place_id: str,
    ) -> list[PlaceSocial]:
        result = await self.session.execute(
            select(PlaceSocial)
            .where(PlaceSocial.place_id == place_id)
            .order_by(PlaceSocial.created_at.asc())
        )
        return list(result.scalars().all())

    async def get(
        self,
        social_id: str,
    ) -> PlaceSocial | None:
        result = await self.session.execute(
            select(PlaceSocial).where(PlaceSocial.id == social_id)
        )
        return result.scalars().first()

    async def find_for_place_type(
        self,
        place_id: str,
        social_type: PlaceSocialType,
    ) -> PlaceSocial | None:
        result = await self.session.execute(
            select(PlaceSocial).where(
                PlaceSocial.place_id == place_id,
                PlaceSocial.social_type == social_type,
            )
        )
        return result.scalars().first()

    async def create(
        self,
        social: PlaceSocial,
    ) -> PlaceSocial:
        self.session.add(social)
        await self.session.commit()
        await self.session.refresh(social)
        return social

    async def delete(
        self,
        social: PlaceSocial,
    ) -> None:
        await self.session.delete(social)
        await self.session.commit()