"""Add unique wallet numbers to user wallets.

Revision ID: 8b1c2d3e4f5a
Revises: 7a89b12c3d4e
Create Date: 2026-08-12
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "8b1c2d3e4f5a"
down_revision = "7e6a2359e129"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ============================================================
    # 1. Add wallet_number as nullable first.
    #
    # This is important because existing wallets already exist.
    # We cannot add a NOT NULL column before backfilling them.
    # ============================================================

    op.add_column(
        "user_wallets",
        sa.Column(
            "wallet_number",
            sa.String(length=12),
            nullable=True,
        ),
    )

    # ============================================================
    # 2. Generate wallet numbers for existing wallets.
    #
    # Start from 100000000001.
    #
    # row_number() guarantees a different number for every
    # existing wallet in this migration.
    #
    # ORDER BY id gives us deterministic assignment.
    # ============================================================

    op.execute(
        """
        UPDATE user_wallets AS uw
        SET wallet_number =
            LPAD(
                (
                    100000000000
                    + numbered.row_number
                )::text,
                12,
                '0'
            )
        FROM (
            SELECT
                id,
                ROW_NUMBER() OVER (ORDER BY id) AS row_number
            FROM user_wallets
            WHERE wallet_number IS NULL
        ) AS numbered
        WHERE uw.id = numbered.id
          AND uw.wallet_number IS NULL
        """
    )

    # ============================================================
    # 3. Safety check.
    #
    # Do not continue if any existing wallet failed to receive
    # a wallet number.
    # ============================================================

    remaining = op.get_bind().execute(
        sa.text(
            """
            SELECT COUNT(*)
            FROM user_wallets
            WHERE wallet_number IS NULL
            """
        )
    ).scalar_one()

    if remaining != 0:
        raise RuntimeError(
            "Wallet migration failed: "
            f"{remaining} wallets still have no wallet_number."
        )

    # ============================================================
    # 4. Create UNIQUE index.
    #
    # This guarantees that two wallets can never have the same
    # wallet number.
    # ============================================================

    op.create_index(
        "ix_user_wallets_wallet_number",
        "user_wallets",
        ["wallet_number"],
        unique=True,
    )

    # ============================================================
    # 5. Make wallet_number mandatory.
    # ============================================================

    op.alter_column(
        "user_wallets",
        "wallet_number",
        existing_type=sa.String(length=12),
        nullable=False,
    )


def downgrade() -> None:
    # ============================================================
    # Remove the unique index first.
    # ============================================================

    op.drop_index(
        "ix_user_wallets_wallet_number",
        table_name="user_wallets",
    )

    # ============================================================
    # Remove wallet_number.
    # ============================================================

    op.drop_column(
        "user_wallets",
        "wallet_number",
    )
