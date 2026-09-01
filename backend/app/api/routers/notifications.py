"""Notifications API routes."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.models.user import User
from app.schemas.social import NotificationRead, UnreadCountRead
from app.services.social_service import SocialService


router = APIRouter(prefix="/notifications", tags=["Notifications"])


# ============================================================
# List notifications
# ============================================================


@router.get(
    "",
    response_model=list[NotificationRead],
)
async def list_notifications(
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[NotificationRead]:
    service = SocialService(session)

    items = await service.list_notifications(
        user_id=current_user.id,
        offset=offset,
        limit=limit,
    )

    return [NotificationRead(**item) for item in items]


# ============================================================
# Unread count
# ============================================================


@router.get(
    "/unread-count",
    response_model=UnreadCountRead,
)
async def get_unread_count(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> UnreadCountRead:
    service = SocialService(session)

    count = await service.unread_count(
        user_id=current_user.id,
    )

    return UnreadCountRead(count=count)


# ============================================================
# Mark one notification as read
# ============================================================


@router.post(
    "/{notification_id}/read",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def mark_notification_read(
    notification_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    service = SocialService(session)

    marked = await service.mark_read(
        user_id=current_user.id,
        notification_id=notification_id,
    )

    if not marked:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found",
        )
