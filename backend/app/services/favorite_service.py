"""Service layer for user favorites."""

from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.favorite import UserFavorite
from app.models.place import Place
from app.repositories.favorite_repository import FavoriteRepository
from app.repositories.place_repository import PlaceRepository


class FavoriteService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repo = FavoriteRepository(session)
        self.place_repo = PlaceRepository(session)

    async def _get_active_place(self, place_id: str) -> Place:
        """Retrieve a non-deleted, active place or raise 404."""
        result = await self.place_repo.get_place(place_id)
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Place not found",
            )
        return result

    async def add_favorite(
        self,
        user_id: UUID | str,
        place_id: str,
    ) -> UserFavorite:
        # Validate place exists (soft-delete aware)
        await self._get_active_place(place_id)

        existing = await self.repo.get_favorite(user_id, place_id)
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Place is already in your favorites",
            )

        return await self.repo.add_favorite(user_id, place_id)

    async def remove_favorite(
        self,
        user_id: UUID | str,
        place_id: str,
    ) -> None:
        favorite = await self.repo.get_favorite(user_id, place_id)
        if favorite is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Favorite not found",
            )
        await self.repo.remove_favorite(favorite)

    async def get_user_favorites(
        self,
        user_id: UUID | str,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> list[Place]:
        return await self.repo.get_favorite_places(
            user_id,
            offset=offset,
            limit=limit,
        )

    async def is_favorite(
        self,
        user_id: UUID | str,
        place_id: str,
    ) -> bool:
        return await self.repo.get_favorite(user_id, place_id) is not None
