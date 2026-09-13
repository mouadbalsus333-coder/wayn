"""Service for user device / FCM token management."""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.device_repository import DeviceRepository
from app.schemas.device import DeviceListResponse, DeviceRead


class DeviceService:
    """Service for device registration, lookup, and deactivation."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.repository = DeviceRepository(session)

    async def register_or_update(
        self,
        *,
        user_id: UUID,
        device_id: str,
        fcm_token: str,
        platform: str,
    ) -> DeviceRead:
        """Create or update a device for the given user + device_id."""
        device = await self.repository.register_or_update(
            user_id=user_id,
            device_id=device_id,
            fcm_token=fcm_token,
            platform=platform,
        )
        return DeviceRead.model_validate(device)

    async def deactivate(
        self,
        *,
        device_id: UUID,
        user_id: UUID,
    ) -> bool:
        """Deactivate a user's device (soft delete).

        The router passes ``device_id`` as ``UserDevice.id`` (the
        database UUID returned by ``DeviceRead.id``). Returns False if
        device not found or doesn't belong to this user.
        """
        device = await self.repository.get_by_id(device_id)
        if device is None or device.user_id != user_id:
            return False
        return await self.repository.deactivate_by_device_id(device_id)

    async def list_active_devices(self, user_id: UUID) -> DeviceListResponse:
        """Return active devices for a user (never exposes FCM token)."""
        devices = await self.repository.get_active_by_user(user_id)
        items = [DeviceRead.model_validate(d) for d in devices]
        return DeviceListResponse(devices=items)
