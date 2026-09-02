"""Add admin wallet recharge (financial audit + permission).

Revision ID: d4f8a1b2c3e7
Revises: a1f2b3c4d5e6
Create Date: 2026-09-02 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "d4f8a1b2c3e7"
down_revision = "a1f2b3c4d5e6"
branch_labels = None
depends_on = None


PERMISSION_NAME = "wallet.recharge"
PERMISSION_DESCRIPTION = "Recharge user wallets from the admin panel"
SUPER_ADMIN_ROLE = "super_admin"


def _add_enum_value() -> None:
    """
    Add ADMIN_RECHARGE to the existing wallet_transaction_type enum.

    PostgreSQL 12+ allows ALTER TYPE ... ADD VALUE inside a transaction
    as long as the new value is NOT used in that same transaction.
    This migration never inserts rows using the new value, so this is safe.
    """
    op.execute(
        "ALTER TYPE wallet_transaction_type "
        "ADD VALUE IF NOT EXISTS 'ADMIN_RECHARGE'"
    )


def _create_recharges_table() -> None:
    op.create_table(
        "wallet_admin_recharges",
        # Identity
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        # Link to the wallet ledger entry created for this recharge.
        # RESTRICT so the audit trail can never silently disappear
        # together with its WalletTransaction.
        sa.Column("transaction_id", sa.Uuid(), nullable=False),
        # Target wallet / user (frozen at operation time)
        sa.Column("wallet_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("wallet_number", sa.String(length=12), nullable=False),
        # Financial snapshot (computed by the backend only)
        sa.Column("amount", sa.BigInteger(), nullable=False),
        sa.Column("balance_before", sa.BigInteger(), nullable=False),
        sa.Column("balance_after", sa.BigInteger(), nullable=False),
        # Admin (actor)
        sa.Column("admin_id", sa.Integer(), nullable=False),
        sa.Column("admin_email", sa.String(length=320), nullable=False),
        # Operation metadata
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column(
            "status",
            sa.Enum(
                "PENDING",
                "CONFIRMED",
                "FAILED",
                name="wallet_admin_recharge_status",
            ),
            server_default="CONFIRMED",
            nullable=False,
        ),
        # Idempotency: one key per admin, same convention as
        # wallet_transfers (sender-scoped unique key).
        sa.Column("idempotency_key", sa.String(length=100), nullable=True),
        # Request metadata (audit)
        sa.Column("ip_address", sa.String(length=64), nullable=True),
        sa.Column("user_agent", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["transaction_id"],
            ["wallet_transactions.id"],
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["wallet_id"],
            ["user_wallets.id"],
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["admin_id"],
            ["admin_users.id"],
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "transaction_id",
            name="uq_wallet_admin_recharges_transaction_id",
        ),
    )

    op.create_index(
        op.f("ix_wallet_admin_recharges_user_id"),
        "wallet_admin_recharges",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_wallet_admin_recharges_wallet_id"),
        "wallet_admin_recharges",
        ["wallet_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_wallet_admin_recharges_admin_id"),
        "wallet_admin_recharges",
        ["admin_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_wallet_admin_recharges_wallet_number"),
        "wallet_admin_recharges",
        ["wallet_number"],
        unique=False,
    )
    op.create_index(
        op.f("ix_wallet_admin_recharges_status"),
        "wallet_admin_recharges",
        ["status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_wallet_admin_recharges_created_at"),
        "wallet_admin_recharges",
        ["created_at"],
        unique=False,
    )
    op.create_index(
        "uq_wallet_admin_recharges_admin_idempotency",
        "wallet_admin_recharges",
        ["admin_id", "idempotency_key"],
        unique=True,
    )


def _grant_permission() -> None:
    """
    Create the wallet.recharge permission and grant it to the
    super_admin role only (insert-if-missing, idempotent).
    """
    op.execute(
        "INSERT INTO permissions (name, description) "
        f"VALUES ('{PERMISSION_NAME}', '{PERMISSION_DESCRIPTION}') "
        "ON CONFLICT (name) DO NOTHING"
    )

    op.execute(
        "INSERT INTO role_permissions (role_id, permission_id) "
        "SELECT r.id, p.id "
        "FROM roles r, permissions p "
        f"WHERE r.name = '{SUPER_ADMIN_ROLE}' "
        f"AND p.name = '{PERMISSION_NAME}' "
        "ON CONFLICT DO NOTHING"
    )


def _revoke_permission() -> None:
    op.execute(
        "DELETE FROM role_permissions "
        "WHERE permission_id IN ("
        "SELECT id FROM permissions "
        f"WHERE name = '{PERMISSION_NAME}')"
    )

    op.execute(
        "DELETE FROM admin_user_permissions "
        "WHERE permission_id IN ("
        "SELECT id FROM permissions "
        f"WHERE name = '{PERMISSION_NAME}')"
    )

    op.execute(
        "DELETE FROM permissions "
        f"WHERE name = '{PERMISSION_NAME}'"
    )


def upgrade() -> None:
    """Add ADMIN_RECHARGE type, the audit table, and the permission."""
    _add_enum_value()
    _create_recharges_table()
    _grant_permission()


def downgrade() -> None:
    """
    Revert the migration.

    Removing a value from a native PostgreSQL enum is not supported
    directly; the type must be rebuilt. This is only safe when NO
    wallet_transactions row uses ADMIN_RECHARGE. If any row uses it,
    this downgrade raises and leaves the database untouched instead of
    deleting or corrupting financial data.
    """
    connection = op.get_bind()

    used_count = connection.execute(
        sa.text(
            "SELECT COUNT(*) FROM wallet_transactions "
            "WHERE type = 'ADMIN_RECHARGE'"
        )
    ).scalar_one()

    if used_count > 0:
        raise RuntimeError(
            "Cannot downgrade: wallet_transactions contains "
            f"{used_count} row(s) using wallet_transaction_type "
            "'ADMIN_RECHARGE'. Removing this enum value would break "
            "existing financial records."
        )

    # Revert permission
    _revoke_permission()

    # Drop the audit table and its indexes
    op.drop_index(
        "uq_wallet_admin_recharges_admin_idempotency",
        table_name="wallet_admin_recharges",
    )
    op.drop_index(
        op.f("ix_wallet_admin_recharges_created_at"),
        table_name="wallet_admin_recharges",
    )
    op.drop_index(
        op.f("ix_wallet_admin_recharges_status"),
        table_name="wallet_admin_recharges",
    )
    op.drop_index(
        op.f("ix_wallet_admin_recharges_wallet_number"),
        table_name="wallet_admin_recharges",
    )
    op.drop_index(
        op.f("ix_wallet_admin_recharges_admin_id"),
        table_name="wallet_admin_recharges",
    )
    op.drop_index(
        op.f("ix_wallet_admin_recharges_wallet_id"),
        table_name="wallet_admin_recharges",
    )
    op.drop_index(
        op.f("ix_wallet_admin_recharges_user_id"),
        table_name="wallet_admin_recharges",
    )
    op.drop_table("wallet_admin_recharges")

    op.execute("DROP TYPE IF EXISTS wallet_admin_recharge_status")

    # ------------------------------------------------------------
    # Rebuild wallet_transaction_type without ADMIN_RECHARGE.
    # Safe: no rows use the value (verified above).
    # ------------------------------------------------------------

    connection.execute(
        sa.text(
            "ALTER TYPE wallet_transaction_type "
            "RENAME TO wallet_transaction_type_old"
        )
    )

    connection.execute(
        sa.text(
            "CREATE TYPE wallet_transaction_type AS ENUM ("
            "'CONTRIBUTION', 'TASK_REWARD', 'ACHIEVEMENT', 'GIFT', "
            "'STORE_PURCHASE', 'TRANSFER', 'SUBSCRIPTION', 'REFUND', "
            "'PENALTY', 'ADJUSTMENT')"
        )
    )

    connection.execute(
        sa.text(
            "ALTER TABLE wallet_transactions "
            "ALTER COLUMN type TYPE wallet_transaction_type "
            "USING type::text::wallet_transaction_type"
        )
    )

    connection.execute(
        sa.text("DROP TYPE wallet_transaction_type_old")
    )
