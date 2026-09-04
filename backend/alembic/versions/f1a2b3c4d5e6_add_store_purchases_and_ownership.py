"""Add store availability, purchases, and ownership.

Revision ID: f1a2b3c4d5e6
Revises: d4f8a1b2c3e7
Create Date: 2026-09-03 00:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f1a2b3c4d5e6"
down_revision: Union[str, Sequence[str], None] = "d4f8a1b2c3e7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        "ALTER TYPE store_item_currency ADD VALUE IF NOT EXISTS 'FREE'"
    )
    op.execute(
        "ALTER TYPE user_point_transaction_type "
        "ADD VALUE IF NOT EXISTS 'STORE_PURCHASE'"
    )

    op.add_column(
        "store_items",
        sa.Column(
            "available_from",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.add_column(
        "store_items",
        sa.Column(
            "available_until",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.add_column(
        "store_items",
        sa.Column(
            "ownership_duration_days",
            sa.Integer(),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_store_items_available_from",
        "store_items",
        ["available_from"],
        unique=False,
    )
    op.create_index(
        "ix_store_items_available_until",
        "store_items",
        ["available_until"],
        unique=False,
    )

    op.create_table(
        "store_ownerships",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("item_id", sa.Uuid(), nullable=False),
        sa.Column(
            "quantity",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "expires_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "quantity > 0",
            name="ck_store_ownerships_quantity_positive",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["item_id"],
            ["store_items.id"],
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "item_id",
            name="uq_store_ownerships_user_item",
        ),
    )
    op.create_index(
        "ix_store_ownerships_user_id",
        "store_ownerships",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_store_ownerships_item_id",
        "store_ownerships",
        ["item_id"],
        unique=False,
    )
    op.create_index(
        "ix_store_ownerships_expires_at",
        "store_ownerships",
        ["expires_at"],
        unique=False,
    )

    store_item_currency = sa.dialects.postgresql.ENUM(
        "POINTS",
        "COINS",
        "FREE",
        name="store_item_currency",
        create_type=False,
    )

    op.create_table(
        "store_purchases",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("item_id", sa.Uuid(), nullable=False),
        sa.Column("currency", store_item_currency, nullable=False),
        sa.Column("amount", sa.BigInteger(), nullable=False),
        sa.Column(
            "quantity",
            sa.Integer(),
            server_default="1",
            nullable=False,
        ),
        sa.Column("idempotency_key", sa.String(length=100), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "amount >= 0",
            name="ck_store_purchases_amount_non_negative",
        ),
        sa.CheckConstraint(
            "quantity > 0",
            name="ck_store_purchases_quantity_positive",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["item_id"],
            ["store_items.id"],
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "idempotency_key",
            name="uq_store_purchases_user_idempotency",
        ),
    )
    op.create_index(
        "ix_store_purchases_user_id",
        "store_purchases",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_store_purchases_item_id",
        "store_purchases",
        ["item_id"],
        unique=False,
    )
    op.create_index(
        "ix_store_purchases_created_at",
        "store_purchases",
        ["created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_store_purchases_created_at", table_name="store_purchases")
    op.drop_index("ix_store_purchases_item_id", table_name="store_purchases")
    op.drop_index("ix_store_purchases_user_id", table_name="store_purchases")
    op.drop_table("store_purchases")

    op.drop_index("ix_store_ownerships_expires_at", table_name="store_ownerships")
    op.drop_index("ix_store_ownerships_item_id", table_name="store_ownerships")
    op.drop_index("ix_store_ownerships_user_id", table_name="store_ownerships")
    op.drop_table("store_ownerships")

    op.drop_index("ix_store_items_available_until", table_name="store_items")
    op.drop_index("ix_store_items_available_from", table_name="store_items")
    op.drop_column("store_items", "ownership_duration_days")
    op.drop_column("store_items", "available_until")
    op.drop_column("store_items", "available_from")

    # PostgreSQL cannot safely remove an enum value in place.
    # FREE remains in the enum on downgrade by design.
