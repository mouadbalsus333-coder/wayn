"""Configurable point reward settings."""

from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class PointRewardSetting(Base):
    __tablename__ = "point_reward_settings"

    key: Mapped[str] = mapped_column(
        sa.String(100),
        primary_key=True,
    )

    points: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        sa.String(255),
        nullable=True,
    )

    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=True,
        server_default=sa.text("true"),
    )

    updated_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        onupdate=sa.func.now(),
        nullable=False,
    )