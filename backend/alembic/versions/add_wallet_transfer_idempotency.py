"""Add idempotency key to wallet transfers.

Revision ID: 7f1a9c2e4b6d
Revises: c224512c79e3
Create Date: 2026-08-13
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "7f1a9c2e4b6d"
down_revision = "c224512c79e3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "wallet_transfers",
        sa.Column(
            "idempotency_key",
            sa.String(100),
            nullable=True,
        ),
    )

    op.create_index(
        "uq_wallet_transfers_sender_idempotency",
        "wallet_transfers",
        ["sender_wallet_id", "idempotency_key"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "uq_wallet_transfers_sender_idempotency",
        table_name="wallet_transfers",
    )

    op.drop_column(
        "wallet_transfers",
        "idempotency_key",
    )