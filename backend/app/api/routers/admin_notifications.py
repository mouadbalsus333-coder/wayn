"""Admin notification routes."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import get_current_admin, require_permission
from app.core.database import get_session
from app.models.admin_user import AdminUser
from app.schemas.admin_notification import (
    AdminNotificationDetailRead,
    AdminNotificationListResponse,
    AdminNotificationRead,
    AdminNotificationSendRequest,
)
from app.services.admin_notification_service import AdminNotificationService

router = APIRouter(prefix="/admin/notifications", tags=["Admin Notifications"])


@router.post(
    "/send",
    response_model=AdminNotificationRead,
    status_code=status.HTTP_201_CREATED,
    summary="Send an admin notification (broadcast)",
)
async def send_notification(
    body: AdminNotificationSendRequest,
    admin: AdminUser = Depends(require_permission("notifications.send")),
    session: AsyncSession = Depends(get_session),
) -> AdminNotificationRead:
    service = AdminNotificationService(session)
    return await service.send_notification(
        admin_id=admin.id,
        request=body,
    )


@router.get(
    "",
    response_model=AdminNotificationListResponse,
    summary="List admin notifications (paginated, newest first)",
)
async def list_notifications(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    admin: AdminUser = Depends(require_permission("notifications.read")),
    session: AsyncSession = Depends(get_session),
) -> AdminNotificationListResponse:
    service = AdminNotificationService(session)
    return await service.list_notifications(page=page, limit=limit)


@router.get(
    "/{notification_id}",
    response_model=AdminNotificationDetailRead,
    summary="Get a single admin notification detail",
)
async def get_notification(
    notification_id: UUID,
    admin: AdminUser = Depends(require_permission("notifications.read")),
    session: AsyncSession = Depends(get_session),
) -> AdminNotificationDetailRead:
    service = AdminNotificationService(session)
    try:
        return await service.get_notification(notification_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        )
