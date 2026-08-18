"""Add wallet transfers.

Revision ID: 4bcee7093fff
Revises: 674c6876772f
Create Date: 2026-08-13 06:57:59.888838
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = "4bcee7093fff"
down_revision = "674c6876772f"
branch_labels = None
depends_on = None


WALLET_TRANSFER_STATUS_ENUM = "wallet_transfer_status"


def _enum_exists(enum_name: str) -> bool:
    bind = op.get_bind()

    result = bind.execute(
        sa.text(
            """
            SELECT EXISTS (
                SELECT 1
                FROM pg_type
                WHERE typname = :enum_name
            )
            """
        ),
        {"enum_name": enum_name},
    )

    return bool(result.scalar())


def upgrade() -> None:
    # ============================================================
    # Existing enum: wallet_asset
    # ============================================================
    #
    # This enum already belongs to the wallet transaction system.
    # We must NOT attempt to create it again.
    #
    wallet_asset_enum = postgresql.ENUM(
        "POINTS",
        "COINS",
        name="wallet_asset",
        create_type=False,
    )

    # ============================================================
    # Transfer status enum
    # ============================================================
    #
    # The database may already contain this enum because a previous
    # attempt or another migration created it.
    #
    if not _enum_exists(WALLET_TRANSFER_STATUS_ENUM):
        wallet_transfer_status_enum = postgresql.ENUM(
            "PENDING",
            "CONFIRMED",
            "FAILED",
            "REVERSED",
            name=WALLET_TRANSFER_STATUS_ENUM,
        )

        wallet_transfer_status_enum.create(
            op.get_bind(),
            checkfirst=True,
        )

    # Use create_type=False here as well because the enum is now
    # guaranteed to exist.
    wallet_transfer_status_enum = postgresql.ENUM(
        "PENDING",
        "CONFIRMED",
        "FAILED",
        "REVERSED",
        name=WALLET_TRANSFER_STATUS_ENUM,
        create_type=False,
    )

    # ============================================================
    # Wallet transfers table
    # ============================================================

    op.create_table(
        "wallet_transfers",

        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),

        sa.Column(
            "sender_wallet_id",
            sa.Uuid(),
            nullable=False,
        ),

        sa.Column(
            "receiver_wallet_id",
            sa.Uuid(),
            nullable=False,
        ),

        sa.Column(
            "asset",
            wallet_asset_enum,
            nullable=False,
        ),

        sa.Column(
            "amount",
            sa.BigInteger(),
            nullable=False,
        ),

        sa.Column(
            "status",
            wallet_transfer_status_enum,
            server_default="PENDING",
            nullable=False,
        ),

        sa.Column(
            "description",
            sa.Text(),
            nullable=True,
        ),

        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),

        sa.Column(
            "completed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),

        sa.ForeignKeyConstraint(
            ["receiver_wallet_id"],
            ["user_wallets.id"],
            ondelete="RESTRICT",
        ),

        sa.ForeignKeyConstraint(
            ["sender_wallet_id"],
            ["user_wallets.id"],
            ondelete="RESTRICT",
        ),

        sa.PrimaryKeyConstraint("id"),
    )

    # ============================================================
    # Indexes
    # ============================================================

    op.create_index(
        "ix_wallet_transfers_asset",
        "wallet_transfers",
        ["asset"],
        unique=False,
    )

    op.create_index(
        "ix_wallet_transfers_created_at",
        "wallet_transfers",
        ["created_at"],
        unique=False,
    )

    op.create_index(
        "ix_wallet_transfers_receiver_wallet_id",
        "wallet_transfers",
        ["receiver_wallet_id"],
        unique=False,
    )

    op.create_index(
        "ix_wallet_transfers_sender_wallet_id",
        "wallet_transfers",
        ["sender_wallet_id"],
        unique=False,
    )

    op.create_index(
        "ix_wallet_transfers_status",
        "wallet_transfers",
        ["status"],
        unique=False,
    )


def downgrade() -> None:
    # ============================================================
    # Drop indexes
    # ============================================================

    op.drop_index(
        "ix_wallet_transfers_status",
        table_name="wallet_transfers",
    )

    op.drop_index(
        "ix_wallet_transfers_sender_wallet_id",
        table_name="wallet_transfers",
    )

    op.drop_index(
        "ix_wallet_transfers_receiver_wallet_id",
        table_name="wallet_transfers",
    )

    op.drop_index(
        "ix_wallet_transfers_created_at",
        table_name="wallet_transfers",
    )

    op.drop_index(
        "ix_wallet_transfers_asset",
        table_name="wallet_transfers",
    )

    # ============================================================
    # Drop table
    # ============================================================

    op.drop_table("wallet_transfers")

    # ============================================================
    # Drop transfer status enum
    # ============================================================
    #
    # wallet_asset is intentionally NOT dropped because it existed
    # before this migration and is still used by wallet_transactions.
    #

    wallet_transfer_status_enum = postgresql.ENUM(
        "PENDING",
        "CONFIRMED",
        "FAILED",
        "REVERSED",
        name=WALLET_TRANSFER_STATUS_ENUM,
    )

    wallet_transfer_status_enum.drop(
        op.get_bind(),
        checkfirst=True,
    )