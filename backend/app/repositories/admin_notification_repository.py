"""Repository for admin notifications."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin_notification import AdminNotification


class AdminNotificationRepository:
    """Repository for admin notification CRUD operations."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(
        self,
        *,
        title: str,
        body: str,
        channel: str,
        notification_type: str,
        sent_by_admin_id: int,
    ) -> AdminNotification:
        notification = AdminNotification(
            title=title,
            body=body,
            channel=channel,
            notification_type=notification_type,
            sent_by_admin_id=sent_by_admin_id,
            status="pending",
        )
        self.session.add(notification)
        await self.session.commit()
        await self.session.refresh(notification)
        return notification

    async def get_by_id(self, notification_id: UUID) -> AdminNotification | None:
        result = await self.session.execute(
            select(AdminNotification).where(AdminNotification.id == notification_id)
        )
        return result.scalar_one_or_none()

    async def list(
        self,
        *,
        page: int,
        limit: int,
    ) -> tuple[list[AdminNotification], int]:
        """List notifications paginated, ordered by newest first."""
        offset = (page - 1) * limit

        result = await self.session.execute(
            select(AdminNotification)
            .order_by(AdminNotification.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        items = list(result.scalars().all())

        count_result = await self.session.execute(
            select(AdminNotification.id)
        )
        total = len(list(count_result.scalars().all()))

        return items, total

    async def update_status(
        self,
        notification_id: UUID,
        *,
        status: str,
        delivered_count: int | None = None,
        failed_count: int | None = None,
    ) -> AdminNotification | None:
        result = await self.session.execute(
            select(AdminNotification).where(AdminNotification.id == notification_id)
        )
        notification = result.scalar_one_or_none()
        if notification is None:
            return None

        notification.status = status
        if delivered_count is not None:
            notification.delivered_count = delivered_count
        if failed_count is not None:
            notification.failed_count = failed_count
        await self.session.commit()
        await self.session.refresh(notification)
        return notification
