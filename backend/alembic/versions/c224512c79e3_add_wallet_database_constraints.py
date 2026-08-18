"""Add wallet database constraints.

Revision ID: c224512c79e3
Revises: 4bcee7093fff
Create Date: 2026-08-13 08:12:22.887283
"""

from alembic import op


# revision identifiers, used by Alembic.
revision = "c224512c79e3"
down_revision = "4bcee7093fff"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ============================================================
    # Wallet balances
    # ============================================================
    # Wallet balances must never become negative.
    op.create_check_constraint(
        "ck_user_wallets_points_balance_non_negative",
        "user_wallets",
        "points_balance >= 0",
    )

    op.create_check_constraint(
        "ck_user_wallets_coins_balance_non_negative",
        "user_wallets",
        "coins_balance >= 0",
    )

    # ============================================================
    # Wallet transfers
    # ============================================================
    # A transfer amount must always be positive.
    op.create_check_constraint(
        "ck_wallet_transfers_amount_positive",
        "wallet_transfers",
        "amount > 0",
    )

    # Sender and receiver must be different wallets.
    op.create_check_constraint(
        "ck_wallet_transfers_different_wallets",
        "wallet_transfers",
        "sender_wallet_id <> receiver_wallet_id",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_wallet_transfers_different_wallets",
        "wallet_transfers",
        type_="check",
    )

    op.drop_constraint(
        "ck_wallet_transfers_amount_positive",
        "wallet_transfers",
        type_="check",
    )

    op.drop_constraint(
        "ck_user_wallets_coins_balance_non_negative",
        "user_wallets",
        type_="check",
    )

    op.drop_constraint(
        "ck_user_wallets_points_balance_non_negative",
        "user_wallets",
        type_="check",
    )