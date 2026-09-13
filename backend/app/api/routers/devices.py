"""Device registration and management routes."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.models.user import User
from app.schemas.device import DeviceListResponse, DeviceRead, DeviceRegisterRequest
from app.services.device_service import DeviceService

router = APIRouter(prefix="/devices", tags=["Devices"])


@router.post(
    "/register",
    response_model=DeviceRead,
    status_code=status.HTTP_201_CREATED,
    summary="Register or update a user device / FCM token",
)
async def register_device(
    body: DeviceRegisterRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> DeviceRead:
    service = DeviceService(session)
    device = await service.register_or_update(
        user_id=current_user.id,
        device_id=body.device_id,
        fcm_token=body.fcm_token,
        platform=body.platform,
    )
    return device


@router.delete(
    "/{device_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deactivate a user's device",
)
async def deactivate_device(
    device_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    service = DeviceService(session)
    ok = await service.deactivate(
        device_id=device_id,
        user_id=current_user.id,
    )
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found or not owned by this user",
        )


@router.get(
    "",
    response_model=DeviceListResponse,
    summary="List active devices for the current user",
)
async def list_devices(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> DeviceListResponse:
    service = DeviceService(session)
    return await service.list_active_devices(current_user.id)
