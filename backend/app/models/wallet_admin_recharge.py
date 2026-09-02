"""Admin wallet recharge model (financial audit record)."""

import enum
from datetime import datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class WalletAdminRechargeStatus(str, enum.Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    FAILED = "FAILED"


class WalletAdminRecharge(Base):
    __tablename__ = "wallet_admin_recharges"

    # ============================================================
    # Identity
    # ============================================================

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    # ============================================================
    # Ledger link
    # ============================================================
    #
    # The WalletTransaction created for this recharge.
    #
    # The FK is RESTRICT in the database so the audit trail can
    # never silently disappear together with its ledger entry.
    # ============================================================

    transaction_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "wallet_transactions.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
        unique=True,
    )

    # ============================================================
    # Target wallet / user (frozen at operation time)
    # ============================================================

    wallet_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "user_wallets.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
        index=True,
    )

    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "users.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
        index=True,
    )

    wallet_number: Mapped[str] = mapped_column(
        sa.String(12),
        nullable=False,
        index=True,
    )

    # ============================================================
    # Financial snapshot (computed by the backend only)
    # ============================================================

    amount: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
    )

    balance_before: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
    )

    balance_after: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
    )

    # ============================================================
    # Admin (actor)
    # ============================================================
    #
    # AdminUser.id is an Integer autoincrement primary key.
    # ============================================================

    admin_id: Mapped[int] = mapped_column(
        sa.Integer,
        sa.ForeignKey(
            "admin_users.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
        index=True,
    )

    admin_email: Mapped[str] = mapped_column(
        sa.String(320),
        nullable=False,
    )

    # ============================================================
    # Operation metadata
    # ============================================================

    note: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    status: Mapped[WalletAdminRechargeStatus] = mapped_column(
        sa.Enum(
            WalletAdminRechargeStatus,
            name="wallet_admin_recharge_status",
            native_enum=True,
        ),
        nullable=False,
        default=WalletAdminRechargeStatus.CONFIRMED,
        server_default=WalletAdminRechargeStatus.CONFIRMED.value,
        index=True,
    )

    # ============================================================
    # Idempotency
    # ============================================================
    #
    # One key per admin, same convention as wallet_transfers
    # (sender-scoped unique key). The database unique index
    # uq_wallet_admin_recharges_admin_idempotency is the final
    # protection against duplicate recharges.
    # ============================================================

    idempotency_key: Mapped[str | None] = mapped_column(
        sa.String(100),
        nullable=True,
    )

    # ============================================================
    # Request metadata (audit)
    # ============================================================

    ip_address: Mapped[str | None] = mapped_column(
        sa.String(64),
        nullable=True,
    )

    user_agent: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    # ============================================================
    # Timestamps
    # ============================================================

    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
        index=True,
    )

    # ============================================================
    # Relationships
    # ============================================================
    #
    # Intentionally no back_populates: the existing models
    # (UserWallet, User, AdminUser, WalletTransaction) are not
    # modified by this feature.
    # ============================================================

    transaction = relationship(
        "WalletTransaction",
        foreign_keys=[transaction_id],
    )

    wallet = relationship(
        "UserWallet",
        foreign_keys=[wallet_id],
    )

    user = relationship(
        "User",
        foreign_keys=[user_id],
    )

    admin = relationship(
        "AdminUser",
        foreign_keys=[admin_id],
    )
