"""Immutable ledger for user point transactions."""

import enum
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class UserPointTransactionType(str, enum.Enum):
    CONTRIBUTION = "CONTRIBUTION"
    TASK_REWARD = "TASK_REWARD"
    ACHIEVEMENT = "ACHIEVEMENT"
    GIFT = "GIFT"
    PENALTY = "PENALTY"
    ADJUSTMENT = "ADJUSTMENT"
    ADMIN_ADJUSTMENT = "ADMIN_ADJUSTMENT"
    STORE_PURCHASE = "STORE_PURCHASE"


class UserPointTransactionStatus(str, enum.Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    REVOKED = "REVOKED"


class UserPointTransaction(Base):
    __tablename__ = "user_point_transactions"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    type: Mapped[UserPointTransactionType] = mapped_column(
        sa.Enum(
            UserPointTransactionType,
            name="user_point_transaction_type",
            native_enum=True,
        ),
        nullable=False,
        index=True,
    )

    status: Mapped[UserPointTransactionStatus] = mapped_column(
        sa.Enum(
            UserPointTransactionStatus,
            name="user_point_transaction_status",
            native_enum=True,
        ),
        nullable=False,
        default=UserPointTransactionStatus.CONFIRMED,
        server_default=UserPointTransactionStatus.CONFIRMED.value,
        index=True,
    )

    amount: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
    )

    balance_after: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    reference_type: Mapped[str | None] = mapped_column(
        sa.String(50),
        nullable=True,
        index=True,
    )

    reference_id: Mapped[UUID | None] = mapped_column(
        sa.Uuid,
        nullable=True,
        index=True,
    )

    # Admin/user/system information and additional metadata.
    extra_data: Mapped[dict] = mapped_column(
        sa.JSON,
        nullable=False,
        default=dict,
        server_default=sa.text("'{}'::json"),
    )

    created_at: Mapped[sa.DateTime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
        index=True,
    )

    user = relationship(
        "User",
        back_populates="point_transactions",
    )
