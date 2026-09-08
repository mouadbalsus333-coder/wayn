"""Add missing wallet permissions.

Revision ID: j5e6f7a8b9c0
Revises: i4d5e6f7a8b9
Create Date: 2026-09-07 00:00:00.000000
"""

from alembic import op


revision = "j5e6f7a8b9c0"
down_revision = "i4d5e6f7a8b9"
branch_labels = None
depends_on = None


PERMISSIONS = {
    "wallet.read": "View user wallets",
    "wallet.transactions": "View wallet transactions",
    "wallet.adjust": "Adjust wallet balances",
}


def upgrade() -> None:
    for name, description in PERMISSIONS.items():
        op.execute(
            "INSERT INTO permissions (name, description) "
            f"VALUES ('{name}', '{description}') "
            "ON CONFLICT (name) DO NOTHING"
        )

    op.execute(
        "INSERT INTO role_permissions (role_id, permission_id) "
        "SELECT r.id, p.id FROM roles r CROSS JOIN permissions p "
        "WHERE r.name = 'super_admin' "
        "AND p.name IN ('wallet.read', 'wallet.transactions', 'wallet.adjust') "
        "ON CONFLICT DO NOTHING"
    )


def downgrade() -> None:
    op.execute(
        "DELETE FROM role_permissions WHERE permission_id IN ("
        "SELECT id FROM permissions WHERE name IN "
        "('wallet.read', 'wallet.transactions', 'wallet.adjust'))"
    )
    op.execute(
        "DELETE FROM admin_user_permissions WHERE permission_id IN ("
        "SELECT id FROM permissions WHERE name IN "
        "('wallet.read', 'wallet.transactions', 'wallet.adjust'))"
    )
    op.execute(
        "DELETE FROM permissions WHERE name IN "
        "('wallet.read', 'wallet.transactions', 'wallet.adjust')"
    )
