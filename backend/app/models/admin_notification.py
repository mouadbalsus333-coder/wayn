from datetime import datetime
from enum import Enum
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy import Index
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


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


class AdminNotification(Base):
    __tablename__ = "admin_notifications"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    title: Mapped[str] = mapped_column(
        sa.String(255),
        nullable=False,
    )

    body: Mapped[str] = mapped_column(
        sa.Text,
        nullable=False,
    )

    channel: Mapped[str] = mapped_column(
        sa.String(20),
        nullable=False,
        default=NotificationChannel.BOTH.value,
        server_default=sa.text(f"'{NotificationChannel.BOTH.value}'"),
    )

    notification_type: Mapped[str] = mapped_column(
        sa.String(50),
        nullable=False,
        default=NotificationType.BROADCAST.value,
        server_default=sa.text(f"'{NotificationType.BROADCAST.value}'"),
    )

    sent_by_admin_id: Mapped[int] = mapped_column(
        sa.ForeignKey("admin_users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    total_recipients: Mapped[int] = mapped_column(
        sa.Integer,
        nullable=True,
    )

    delivered_count: Mapped[int] = mapped_column(
        sa.Integer,
        nullable=False,
        default=0,
        server_default="0",
    )

    failed_count: Mapped[int] = mapped_column(
        sa.Integer,
        nullable=False,
        default=0,
        server_default="0",
    )

    status: Mapped[str] = mapped_column(
        sa.String(30),
        nullable=False,
        default=NotificationStatus.PENDING.value,
        server_default=sa.text(f"'{NotificationStatus.PENDING.value}'"),
        index=True,
    )

    scheduled_at: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    sent_at: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        onupdate=sa.func.now(),
        nullable=False,
    )

    __table_args__ = (
        Index("ix_admin_notifications_status", "status"),
        Index("ix_admin_notifications_sent_by", "sent_by_admin_id"),
        Index("ix_admin_notifications_created_at", "created_at"),
    )

    sent_by = relationship("AdminUser", back_populates="sent_notifications")
