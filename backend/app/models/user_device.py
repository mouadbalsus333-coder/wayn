from datetime import datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy import Index, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class UserDevice(Base):
    __tablename__ = "user_devices"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    device_id: Mapped[str] = mapped_column(
        sa.String(255),
        nullable=False,
    )

    fcm_token: Mapped[str] = mapped_column(
        sa.String(255),
        nullable=False,
    )

    platform: Mapped[str] = mapped_column(
        sa.String(20),
        nullable=False,
    )

    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=True,
        server_default=sa.text("true"),
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
        UniqueConstraint("user_id", "device_id", name="uq_user_devices_user_device"),
        Index("ix_user_devices_fcm_token", "fcm_token"),
        Index("ix_user_devices_is_active", "is_active"),
    )

    user = relationship("User", back_populates="devices")
