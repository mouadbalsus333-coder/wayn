"""Schemas package for the WAYN backend."""

from app.schemas.admin_notification import (
    AdminNotificationDetailRead,
    AdminNotificationListResponse,
    AdminNotificationRead,
    AdminNotificationSendRequest,
    NotificationChannel,
    NotificationStatus,
    NotificationType,
)
from app.schemas.device import (
    DeviceListResponse,
    DeviceRead,
    DeviceRegisterRequest,
)
from app.schemas.social import (
    FollowResult,
    NotificationRead,
    PublicUserRead,
    UnreadCountRead,
)

__all__ = [
    "AdminNotificationDetailRead",
    "AdminNotificationListResponse",
    "AdminNotificationRead",
    "AdminNotificationSendRequest",
    "DeviceListResponse",
    "DeviceRead",
    "DeviceRegisterRequest",
    "NotificationChannel",
    "NotificationRead",
    "NotificationStatus",
    "NotificationType",
    "PublicUserRead",
    "UnreadCountRead",
]
