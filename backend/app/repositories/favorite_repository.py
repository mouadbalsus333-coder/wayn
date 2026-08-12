"""Repository for user_favorites table operations."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.favorite import UserFavorite
from app.models.place import Place


class FavoriteRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_favorite(
        self,
        user_id: UUID | str,
        place_id: UUID | str,
    ) -> UserFavorite | None:
        result = await self.session.execute(
            select(UserFavorite).where(
                UserFavorite.user_id == str(user_id),
                UserFavorite.place_id == str(place_id),
            )
        )
        return result.scalar_one_or_none()

    async def add_favorite(
        self,
        user_id: UUID | str,
        place_id: UUID | str,
    ) -> UserFavorite:
        favorite = UserFavorite(
            user_id=str(user_id),
            place_id=str(place_id),
        )
        self.session.add(favorite)
        await self.session.commit()
        await self.session.refresh(favorite)
        return favorite

    async def remove_favorite(
        self,
        favorite: UserFavorite,
    ) -> None:
        await self.session.delete(favorite)
        await self.session.commit()

    async def list_user_favorites(
        self,
        user_id: UUID | str,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> list[UserFavorite]:
        result = await self.session.execute(
            select(UserFavorite)
            .where(UserFavorite.user_id == str(user_id))
            .order_by(UserFavorite.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return result.scalars().all()

    async def get_favorite_places(
        self,
        user_id: UUID | str,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> list[Place]:
        """Return the Place objects for a user's favorites (excludes soft-deleted)."""
        result = await self.session.execute(
            select(Place)
            .join(
                UserFavorite,
                UserFavorite.place_id == Place.id,
            )
            .where(
                UserFavorite.user_id == str(user_id),
                Place.is_active.is_(True),
                Place.deleted_at.is_(None),
            )
            .order_by(UserFavorite.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return result.scalars().all()
