"""Store banner service."""

from uuid import UUID

from app.models.store_banner import StoreBanner
from app.repositories.store_banner_repository import (
    StoreBannerRepository,
)
from app.schemas.store import (
    StoreBannerCreate,
    StoreBannerUpdate,
)


class StoreBannerService:
    def __init__(
        self,
        repository: StoreBannerRepository,
    ):
        self.repository = repository

    async def get_banners(
        self,
        active_only: bool = False,
    ) -> list[StoreBanner]:
        return await self.repository.list_banners(
            active_only=active_only,
        )

    async def get_banner(
        self,
        banner_id: UUID,
    ) -> StoreBanner | None:
        return await self.repository.get_banner(
            banner_id,
        )

    async def create_banner(
        self,
        data: StoreBannerCreate,
    ) -> StoreBanner:
        banner = StoreBanner(
            title_ar=data.title_ar,
            title_en=data.title_en,
            image_url=data.image_url,
            target_url=data.target_url,
            sort_order=data.sort_order,
            is_active=data.is_active,
            starts_at=data.starts_at,
            ends_at=data.ends_at,
        )

        return await self.repository.create_banner(
            banner,
        )

    async def update_banner(
        self,
        banner: StoreBanner,
        data: StoreBannerUpdate,
    ) -> StoreBanner:
        update_data = data.model_dump(
            exclude_unset=True,
        )

        for field, value in update_data.items():
            setattr(banner, field, value)

        return await self.repository.update_banner(
            banner,
        )

    async def delete_banner(
        self,
        banner: StoreBanner,
    ) -> None:
        await self.repository.delete_banner(
            banner,
        )