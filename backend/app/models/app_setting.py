"""Simple application-wide settings stored as key/value rows."""

from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class AppSetting(Base):
    __tablename__ = "app_settings"

    key: Mapped[str] = mapped_column(
        sa.String(100),
        primary_key=True,
    )

    value: Mapped[str] = mapped_column(
        sa.String(255),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        sa.String(255),
        nullable=True,
    )

    updated_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        onupdate=sa.func.now(),
        nullable=False,
    )
