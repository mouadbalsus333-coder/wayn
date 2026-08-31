"""Configurable point reward rules."""

from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class PointRule(Base):
    __tablename__ = "point_rules"

    id: Mapped[int] = mapped_column(
        sa.Integer,
        primary_key=True,
        autoincrement=True,
    )

    action_key: Mapped[str] = mapped_column(
        sa.String(100),
        unique=True,
        nullable=False,
        index=True,
    )

    points: Mapped[int] = mapped_column(
        sa.Integer,
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
        server_default=sa.true(),
        index=True,
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