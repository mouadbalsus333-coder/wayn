import enum
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class WalletAsset(str, enum.Enum):
    POINTS = "POINTS"
    COINS = "COINS"


class WalletTransactionType(str, enum.Enum):
    CONTRIBUTION = "CONTRIBUTION"
    TASK_REWARD = "TASK_REWARD"
    ACHIEVEMENT = "ACHIEVEMENT"
    GIFT = "GIFT"
    STORE_PURCHASE = "STORE_PURCHASE"
    TRANSFER = "TRANSFER"
    SUBSCRIPTION = "SUBSCRIPTION"
    REFUND = "REFUND"
    PENALTY = "PENALTY"
    ADJUSTMENT = "ADJUSTMENT"


class WalletTransactionStatus(str, enum.Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    REVOKED = "REVOKED"


class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    wallet_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "user_wallets.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    asset: Mapped[WalletAsset] = mapped_column(
        sa.Enum(
            WalletAsset,
            name="wallet_asset",
            native_enum=True,
        ),
        nullable=False,
        index=True,
    )

    type: Mapped[WalletTransactionType] = mapped_column(
        sa.Enum(
            WalletTransactionType,
            name="wallet_transaction_type",
            native_enum=True,
        ),
        nullable=False,
        index=True,
    )

    status: Mapped[WalletTransactionStatus] = mapped_column(
        sa.Enum(
            WalletTransactionStatus,
            name="wallet_transaction_status",
            native_enum=True,
        ),
        nullable=False,
        default=WalletTransactionStatus.CONFIRMED,
        server_default=WalletTransactionStatus.CONFIRMED.value,
        index=True,
    )

    amount: Mapped[int] = mapped_column(
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

    wallet = relationship(
        "UserWallet",
        back_populates="transactions",
    )