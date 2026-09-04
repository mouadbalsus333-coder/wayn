"""Store purchase audit records."""

from datetime import datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base
from app.models.store_item import StoreItemCurrency


class StorePurchase(Base):
    __tablename__ = "store_purchases"
    __table_args__ = (
        sa.UniqueConstraint(
            "user_id",
            "idempotency_key",
            name="uq_store_purchases_user_idempotency",
        ),
    )

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
    item_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey("store_items.id", ondelete="RESTRICT"),
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
    )
    amount: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
    )
    quantity: Mapped[int] = mapped_column(
        sa.Integer,
        nullable=False,
        server_default="1",
    )
    idempotency_key: Mapped[str | None] = mapped_column(
        sa.String(100),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
        index=True,
    )

    item = relationship("StoreItem")
    user = relationship("User")