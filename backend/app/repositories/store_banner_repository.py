"""Store banner repository."""

from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.store_banner import StoreBanner


class StoreBannerRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def list_banners(
        self,
        active_only: bool = False,
    ) -> list[StoreBanner]:
        query = select(StoreBanner)

        if active_only:
            now = datetime.now(timezone.utc)

            query = query.where(
                StoreBanner.is_active.is_(True),
                (
                    StoreBanner.starts_at.is_(None)
                    | (StoreBanner.starts_at <= now)
                ),
                (
                    StoreBanner.ends_at.is_(None)
                    | (StoreBanner.ends_at >= now)
                ),
            )

        query = query.order_by(
            StoreBanner.sort_order,
            StoreBanner.created_at,
        )

        result = await self.session.execute(query)

        return result.scalars().all()

    async def get_banner(
        self,
        banner_id: UUID,
    ) -> StoreBanner | None:
        result = await self.session.execute(
            select(StoreBanner).where(
                StoreBanner.id == banner_id
            )
        )

        return result.scalar_one_or_none()

    async def create_banner(
        self,
        banner: StoreBanner,
    ) -> StoreBanner:
        self.session.add(banner)

        await self.session.commit()
        await self.session.refresh(banner)

        return banner

    async def update_banner(
        self,
        banner: StoreBanner,
    ) -> StoreBanner:
        await self.session.commit()
        await self.session.refresh(banner)

        return banner

    async def delete_banner(
        self,
        banner: StoreBanner,
    ) -> None:
        await self.session.delete(banner)
        await self.session.commit()