"""Wallet transfer model."""

import enum
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base
from app.models.wallet_transaction import WalletAsset


class WalletTransferStatus(str, enum.Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    FAILED = "FAILED"
    REVERSED = "REVERSED"


class WalletTransfer(Base):
    __tablename__ = "wallet_transfers"

    __table_args__ = (
        sa.Index(
            "uq_wallet_transfers_sender_idempotency",
            "sender_wallet_id",
            "idempotency_key",
            unique=True,
        ),
    )

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    sender_wallet_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "user_wallets.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
        index=True,
    )

    receiver_wallet_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "user_wallets.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
        index=True,
    )

    asset: Mapped[WalletAsset] = mapped_column(
        sa.Enum(
            WalletAsset,
            name="wallet_asset",
            native_enum=True,
            create_type=False,
        ),
        nullable=False,
        index=True,
    )

    amount: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
    )

    status: Mapped[WalletTransferStatus] = mapped_column(
        sa.Enum(
            WalletTransferStatus,
            name="wallet_transfer_status",
            native_enum=True,
        ),
        nullable=False,
        default=WalletTransferStatus.PENDING,
        server_default=WalletTransferStatus.PENDING.value,
        index=True,
    )

    description: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    idempotency_key: Mapped[str | None] = mapped_column(
        sa.String(100),
        nullable=True,
    )

    created_at: Mapped[sa.DateTime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
        index=True,
    )

    completed_at: Mapped[sa.DateTime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    # ============================================================
    # Relationships
    # ============================================================

    sender_wallet = relationship(
        "UserWallet",
        foreign_keys=[sender_wallet_id],
        lazy="joined",
    )

    receiver_wallet = relationship(
        "UserWallet",
        foreign_keys=[receiver_wallet_id],
        lazy="joined",
    )