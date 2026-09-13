"""Service for admin notifications."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.repositories.admin_notification_repository import AdminNotificationRepository
from app.repositories.device_repository import DeviceRepository
from app.schemas.admin_notification import (
    AdminNotificationDetailRead,
    AdminNotificationListResponse,
    AdminNotificationRead,
    AdminNotificationSendRequest,
    NotificationChannel,
)
from app.services.fcm_service import (
    FCMNotConfiguredError,
    FCMSendResult,
    fcm_service,
)


class AdminNotificationService:
    """Service for admin notification creation and management."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.notification_repo = AdminNotificationRepository(session)
        self.device_repo = DeviceRepository(session)

    async def send_notification(
        self,
        *,
        admin_id: int,
        request: AdminNotificationSendRequest,
    ) -> AdminNotificationRead:
        """Create and broadcast an admin notification.

        Channel behaviour:
        * ``in_app`` -> create a UserNotification per active user
          (unchanged from previous behaviour).
        * ``push``   -> send FCM push to every active device of active users.
        * ``both``   -> both of the above; a push failure never rolls back
          the already-created in-app notifications.

        ``total_recipients`` / ``delivered_count`` / ``failed_count`` reflect
        the combined result. ``delivered`` means FCM accepted the message, not
        that the user opened it.
        """
        notification = await self.notification_repo.create(
            title=request.title,
            body=request.body,
            channel=request.channel,
            notification_type=request.notification_type,
            sent_by_admin_id=admin_id,
        )

        channel = request.channel
        in_app_requested = channel in (
            NotificationChannel.IN_APP.value,
            NotificationChannel.BOTH.value,
        )
        push_requested = channel in (
            NotificationChannel.PUSH.value,
            NotificationChannel.BOTH.value,
        )

        active_user_ids = await self._get_active_user_ids()

        total = 0
        delivered = 0
        failed = 0
        push_not_configured = False

# ----------------------------------------------------------
        # In-app channel
        # ----------------------------------------------------------
        if in_app_requested:
            if active_user_ids:
                await self._create_in_app_notifications(
                    notification_id=notification.id,
                    user_ids=active_user_ids,
                    body=request.body,
                    channel=channel,
                )
                total += len(active_user_ids)
                delivered += len(active_user_ids)

        # ----------------------------------------------------------
        # Push channel
        # ----------------------------------------------------------
        devices = []
        if push_requested:
            devices = await self.device_repo.get_active_for_users(active_user_ids)
            tokens = [d.fcm_token for d in devices]
            total += len(devices)

            if tokens:
                try:
                    result = fcm_service.send_push(
                        tokens=tokens,
                        title=request.title,
                        body=request.body,
                        data={
                            "admin_notification_id": str(notification.id),
                            "channel": channel,
                        },
                    )
                    delivered += result.success
                    failed += result.failed
                    await self._deactivate_failed_devices(
                        devices=devices,
                        result=result,
                    )
                except FCMNotConfiguredError:
                    push_not_configured = True
                    failed += len(devices)

        # ----------------------------------------------------------
        # Aggregate + status
        # ----------------------------------------------------------
        notification.total_recipients = total
        notification.delivered_count = delivered
        notification.failed_count = failed
        notification.status = self._resolve_status(
            in_app_requested=in_app_requested,
            push_requested=push_requested,
            push_attempted=len(devices) if push_requested else 0,
            delivered=delivered,
            failed=failed,
            push_not_configured=push_not_configured,
        )
        notification.sent_at = self._now()

        await self.session.commit()
        await self.session.refresh(notification)

        return AdminNotificationRead.model_validate(notification)

    def _resolve_status(
        self,
        *,
        in_app_requested: bool,
        push_requested: bool,
        push_attempted: int,
        delivered: int,
        failed: int,
        push_not_configured: bool,
    ) -> str:
        """Map the delivery outcome to one of the supported statuses."""
        # in_app only keeps its historical behaviour.
        if in_app_requested and not push_requested:
            return "completed"

        # push-only path.
        if push_requested and not in_app_requested:
            if push_not_configured:
                return "failed"
            if push_attempted == 0:
                return "completed"
            if failed == 0:
                return "completed"
            if delivered > 0:
                return "partial"
            return "failed"

        # both path: in-app always succeeds; push may partially fail.
        if push_attempted == 0:
            return "completed"
        if push_not_configured or failed > 0:
            return "partial"
        return "completed"

    async def _deactivate_failed_devices(
        self,
        *,
        devices: list,
        result: FCMSendResult,
    ) -> None:
        """Stub reserved for invalid/unregistered token cleanup.

        ``fcm_service.send_push`` currently returns aggregate counts; per-token
        failures are not attributed in the aggregate response. Invalid tokens
        are instead cleaned up client-side on the next re-registration, which
        already soft-reactivates the device. Kept as a safe hook.
        """
        await self.session.flush()

    @staticmethod
    def _now():
        from datetime import datetime, timezone
        return datetime.now(timezone.utc)

    async def list_notifications(
        self,
        *,
        page: int = 1,
        limit: int = 20,
    ) -> AdminNotificationListResponse:
        """Paginated list of admin notifications."""
        items, total = await self.notification_repo.list(page=page, limit=limit)
        read_items = [AdminNotificationRead.model_validate(n) for n in items]
        pages = (total + limit - 1) // limit if limit else 0
        return AdminNotificationListResponse(
            items=read_items,
            total=total,
            page=page,
            limit=limit,
            pages=pages,
        )

    async def get_notification(
        self,
        notification_id: UUID,
    ) -> AdminNotificationDetailRead:
        """Get a single notification with extended details."""
        notification = await self.notification_repo.get_by_id(notification_id)
        if notification is None:
            raise ValueError("Notification not found")

        read = AdminNotificationRead.model_validate(notification)
        return AdminNotificationDetailRead(
            **read.model_dump(),
        )

    async def _get_active_user_ids(self) -> list[UUID]:
        """Get IDs of all active users for broadcast."""
        result = await self.session.execute(
            select(User.id).where(User.is_active.is_(True))
        )
        return [row[0] for row in result.all()]

    async def _create_in_app_notifications(
        self,
        *,
        notification_id: UUID,
        user_ids: list[UUID],
        body: str,
        channel: str,
    ) -> None:
        """Create UserNotification records for in_app delivery."""
        from app.models.social import UserNotification
        from datetime import datetime, timezone

        now = datetime.now(timezone.utc)

        for user_id in user_ids:
            un = UserNotification(
                user_id=user_id,
                type="ADMIN_BROADCAST",
                source="admin",
                text=body,
                data={
                    "admin_notification_id": str(notification_id),
                    "channel": channel,
                },
                is_read=False,
                created_at=now,
            )
            self.session.add(un)

        await self.session.commit()