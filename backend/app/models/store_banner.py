"""Store banner model."""

from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class StoreBanner(Base):
    __tablename__ = "store_banners"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    title_ar: Mapped[str | None] = mapped_column(
        sa.String(200),
        nullable=True,
    )

    title_en: Mapped[str | None] = mapped_column(
        sa.String(200),
        nullable=True,
    )

    image_url: Mapped[str] = mapped_column(
        sa.String(500),
        nullable=False,
    )

    target_url: Mapped[str | None] = mapped_column(
        sa.String(500),
        nullable=True,
    )

    sort_order: Mapped[int] = mapped_column(
        sa.Integer,
        nullable=False,
        default=0,
        server_default="0",
        index=True,
    )

    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=True,
        server_default=sa.true(),
        index=True,
    )

    starts_at: Mapped[sa.DateTime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
        index=True,
    )

    ends_at: Mapped[sa.DateTime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
        index=True,
    )

    created_at: Mapped[sa.DateTime] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
        index=True,
    )

    updated_at: Mapped[sa.DateTime] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    )