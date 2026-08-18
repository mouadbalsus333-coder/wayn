"""Store item model."""

from enum import Enum
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class StoreItemType(str, Enum):
    AVATAR = "AVATAR"
    FRAME = "FRAME"
    GIFT = "GIFT"
    SUBSCRIPTION = "SUBSCRIPTION"
    PROFILE_BACKGROUND = "PROFILE_BACKGROUND"
    BADGE = "BADGE"
    OTHER = "OTHER"


class StoreItemCurrency(str, Enum):
    POINTS = "POINTS"
    COINS = "COINS"


class StoreItem(Base):
    __tablename__ = "store_items"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    category_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "store_categories.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    name_ar: Mapped[str] = mapped_column(
        sa.String(150),
        nullable=False,
    )

    name_en: Mapped[str] = mapped_column(
        sa.String(150),
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

    item_type: Mapped[StoreItemType] = mapped_column(
        sa.Enum(
            StoreItemType,
            name="store_item_type",
            native_enum=True,
            create_type=False,
        ),
        nullable=False,
        index=True,
    )

    currency: Mapped[StoreItemCurrency] = mapped_column(
        sa.Enum(
            StoreItemCurrency,
            name="store_item_currency",
            native_enum=True,
            create_type=False,
        ),
        nullable=False,
        index=True,
    )

    price: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
    )

    image_url: Mapped[str | None] = mapped_column(
        sa.String(500),
        nullable=True,
    )

    asset_id: Mapped[str | None] = mapped_column(
        sa.String(150),
        nullable=True,
    )

    duration_days: Mapped[int | None] = mapped_column(
        sa.Integer,
        nullable=True,
    )

    stock: Mapped[int | None] = mapped_column(
        sa.Integer,
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

    category = relationship(
        "StoreCategory",
        back_populates="items",
    )