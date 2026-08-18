"""User wallet model."""

from datetime import datetime
from enum import Enum
from uuid import UUID

import secrets
import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class WalletStatus(str, Enum):
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    HIDDEN = "HIDDEN"


def generate_wallet_number() -> str:
    """
    Generate a unique wallet number.

    The database UNIQUE constraint is the final protection
    against duplicate wallet numbers.
    """
    return "W" + "".join(
        str(secrets.randbelow(10))
        for _ in range(11)
    )


class UserWallet(Base):
    __tablename__ = "user_wallets"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )

    wallet_number: Mapped[str] = mapped_column(
        sa.String(12),
        unique=True,
        nullable=False,
        index=True,
        default=generate_wallet_number,
    )

    points_balance: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
        default=0,
        server_default="0",
    )

    coins_balance: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
        default=0,
        server_default="0",
    )

    # ============================================================
    # Wallet status
    # ============================================================

    status: Mapped[WalletStatus] = mapped_column(
        sa.Enum(
            WalletStatus,
            name="wallet_status",
            native_enum=True,
        ),
        nullable=False,
        default=WalletStatus.ACTIVE,
        server_default=WalletStatus.ACTIVE.value,
        index=True,
    )

    status_reason: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    status_changed_at: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    status_changed_by: Mapped[int | None] = mapped_column(
        sa.Integer,
        nullable=True,
    )

    suspended_until: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    # ============================================================
    # Transfer protection
    # ============================================================

    transfers_blocked_until: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    transfers_block_reason: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    # ============================================================
    # Relationships
    # ============================================================

    user = relationship(
        "User",
        back_populates="wallet",
        uselist=False,
    )

    transactions = relationship(
        "WalletTransaction",
        back_populates="wallet",
        cascade="all, delete-orphan",
        order_by="WalletTransaction.created_at.desc()",
    )