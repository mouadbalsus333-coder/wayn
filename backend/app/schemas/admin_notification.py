"""Pydantic schemas for admin notifications."""

from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field


class NotificationChannel(str, Enum):
    IN_APP = "in_app"
    PUSH = "push"
    BOTH = "both"


class NotificationType(str, Enum):
    BROADCAST = "broadcast"


class NotificationStatus(str, Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    PARTIAL = "partial"
    FAILED = "failed"


class AdminNotificationSendRequest(BaseModel):
    """Request body for sending an admin notification."""

    title: str = Field(
        min_length=1,
        max_length=255,
        description="Notification title.",
    )
    body: str = Field(
        min_length=1,
        max_length=4000,
        description="Notification body text.",
    )
    channel: str = Field(
        default="both",
        pattern=r"^(in_app|push|both)$",
        description="Delivery channel: 'in_app', 'push', or 'both'.",
    )
    notification_type: str = Field(
        default="broadcast",
        pattern=r"^(broadcast)$",
        description="Notification type (currently only 'broadcast' is supported).",
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "title": "عنوان الإشعار",
                    "body": "نص الإشعار هنا",
                    "channel": "both",
                    "notification_type": "broadcast",
                }
            ]
        }
    }


class AdminNotificationRead(BaseModel):
    """Single admin notification with summary statistics."""

    id: UUID
    title: str
    body: str
    channel: str
    notification_type: str
    sent_by_admin_id: int
    total_recipients: int | None
    delivered_count: int
    failed_count: int
    status: str
    scheduled_at: datetime | None
    sent_at: datetime | None
    created_at: datetime
    updated_at: datetime | None

    model_config = {
        "from_attributes": True,
    }


class AdminNotificationDetailRead(AdminNotificationRead):
    """Extended read with in_app delivery summary (per-user notification count)."""

    in_app_notification_count: int | None = None


class AdminNotificationListResponse(BaseModel):
    """Paginated list of admin notifications with X-Total-Count header."""

    items: list[AdminNotificationRead]
    total: int
    page: int
    limit: int
    pages: int
