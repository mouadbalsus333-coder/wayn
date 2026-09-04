"""Grant Store write access to super_admin only.

Revision ID: g2b3c4d5e6f7
Revises: f1a2b3c4d5e6
Create Date: 2026-09-04 00:00:00.000000
"""

from alembic import op


revision = "g2b3c4d5e6f7"
down_revision = "f1a2b3c4d5e6"
branch_labels = None
depends_on = None


PERMISSION_NAME = "store.write"
PERMISSION_DESCRIPTION = "Create and update store content"
SUPER_ADMIN_ROLE = "super_admin"


def upgrade() -> None:
    """Create store.write and grant it exclusively to super_admin."""
    op.execute(
        "INSERT INTO permissions (name, description) "
        f"VALUES ('{PERMISSION_NAME}', '{PERMISSION_DESCRIPTION}') "
        "ON CONFLICT (name) DO NOTHING"
    )

    op.execute(
        "DELETE FROM admin_user_permissions "
        "WHERE permission_id IN ("
        "SELECT id FROM permissions "
        f"WHERE name = '{PERMISSION_NAME}')"
    )

    op.execute(
        "DELETE FROM role_permissions "
        "WHERE permission_id IN ("
        "SELECT p.id FROM permissions p "
        f"WHERE p.name = '{PERMISSION_NAME}') "
        "AND role_id NOT IN ("
        "SELECT id FROM roles "
        f"WHERE name = '{SUPER_ADMIN_ROLE}')"
    )

    op.execute(
        "INSERT INTO role_permissions (role_id, permission_id) "
        "SELECT r.id, p.id "
        "FROM roles r, permissions p "
        f"WHERE r.name = '{SUPER_ADMIN_ROLE}' "
        f"AND p.name = '{PERMISSION_NAME}' "
        "ON CONFLICT DO NOTHING"
    )


def downgrade() -> None:
    """Remove the Store write permission and all of its assignments."""
    op.execute(
        "DELETE FROM admin_user_permissions "
        "WHERE permission_id IN ("
        "SELECT id FROM permissions "
        f"WHERE name = '{PERMISSION_NAME}')"
    )
    op.execute(
        "DELETE FROM role_permissions "
        "WHERE permission_id IN ("
        "SELECT id FROM permissions "
        f"WHERE name = '{PERMISSION_NAME}')"
    )
    op.execute(
        "DELETE FROM permissions "
        f"WHERE name = '{PERMISSION_NAME}'"
    )
