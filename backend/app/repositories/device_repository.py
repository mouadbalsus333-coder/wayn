"""Repository for user devices / FCM tokens."""

from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_device import UserDevice


class DeviceRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_id(self, device_id: UUID) -> UserDevice | None:
        result = await self.session.execute(
            select(UserDevice).where(UserDevice.id == device_id)
        )
        return result.scalar_one_or_none()

    async def get_by_user_and_device_id(
        self,
        user_id: UUID,
        device_id: str,
    ) -> UserDevice | None:
        result = await self.session.execute(
            select(UserDevice).where(
                UserDevice.user_id == user_id,
                UserDevice.device_id == device_id,
            )
        )
        return result.scalar_one_or_none()

    async def register_or_update(
        self,
        *,
        user_id: UUID,
        device_id: str,
        fcm_token: str,
        platform: str,
    ) -> UserDevice:
        """Create or update a device for the given user and device_id."""
        existing = await self.get_by_user_and_device_id(
            user_id=user_id,
            device_id=device_id,
        )

        if existing is not None:
            existing.fcm_token = fcm_token
            existing.platform = platform
            existing.is_active = True
            existing.updated_at = datetime.now(timezone.utc)
            await self.session.commit()
            await self.session.refresh(existing)
            return existing

        now = datetime.now(timezone.utc)
        device = UserDevice(
            user_id=user_id,
            device_id=device_id,
            fcm_token=fcm_token,
            platform=platform,
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        self.session.add(device)
        await self.session.commit()
        await self.session.refresh(device)
        return device

    async def get_active_by_user(self, user_id: UUID) -> list[UserDevice]:
        """Return active devices for a user, ordered by creation date desc."""
        result = await self.session.execute(
            select(UserDevice)
            .where(UserDevice.user_id == user_id, UserDevice.is_active.is_(True))
            .order_by(UserDevice.created_at.desc())
        )
        return list(result.scalars().all())

    async def get_active_for_users(self, user_ids: list[UUID]) -> list[UserDevice]:
        """Return all active devices belonging to any of the given users.

        This powers push broadcasts: it fetches every active FCM token for
        a group of recipients, supporting multi-device users.
        """
        if not user_ids:
            return []

        result = await self.session.execute(
            select(UserDevice).where(
                UserDevice.user_id.in_(user_ids),
                UserDevice.is_active.is_(True),
            )
        )
        return list(result.scalars().all())

    async def deactivate_by_device_ids(self, device_ids: list[UUID]) -> int:
        """Soft-deactivate multiple devices by their UUIDs (bulk).

        Returns the number of rows updated. Used when FCM reports tokens as
        unregistered/invalid so we stop sending to dead devices while keeping
        the records for audit.
        """
        if not device_ids:
            return 0

        result = await self.session.execute(
            update(UserDevice)
            .where(
                UserDevice.id.in_(device_ids),
                UserDevice.is_active.is_(True),
            )
            .values(is_active=False, updated_at=datetime.now(timezone.utc))
            .execution_options(synchronize_session="fetch")
        )
        await self.session.commit()
        return result.rowcount

    async def deactivate_by_device_id(self, device_id: UUID) -> bool:
        """Soft-deactivate a device by its UUID."""
        result = await self.session.execute(
            update(UserDevice)
            .where(
                UserDevice.id == device_id,
                UserDevice.is_active.is_(True),
            )
            .values(is_active=False, updated_at=datetime.now(timezone.utc))
            .execution_options(synchronize_session="fetch")
        )
        await self.session.commit()
        return result.rowcount > 0
