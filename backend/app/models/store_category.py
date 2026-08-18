"""Store category model."""

from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class StoreCategory(Base):
    __tablename__ = "store_categories"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    name_ar: Mapped[str] = mapped_column(
        sa.String(100),
        nullable=False,
    )

    name_en: Mapped[str] = mapped_column(
        sa.String(100),
        nullable=False,
    )

    description_ar: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    description_en: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    icon_url: Mapped[str | None] = mapped_column(
        sa.String(500),
        nullable=True,
    )

    image_url: Mapped[str | None] = mapped_column(
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

    items = relationship(
        "StoreItem",
        back_populates="category",
        cascade="all, delete-orphan",
        order_by="StoreItem.sort_order",
    )