"""Add Admin review permissions.

Revision ID: i4d5e6f7a8b9
Revises: h3c4d5e6f7a8
Create Date: 2026-09-05 00:00:00.000000
"""

from alembic import op


revision = "i4d5e6f7a8b9"
down_revision = "h3c4d5e6f7a8"
branch_labels = None
depends_on = None


PERMISSIONS = {
    "reviews.read": "View reviews",
    "reviews.moderate": "Manage review visibility",
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
        "WHERE r.name IN ('super_admin', 'moderator') "
        "AND p.name IN ('reviews.read', 'reviews.moderate') "
        "ON CONFLICT DO NOTHING"
    )
    op.execute(
        "INSERT INTO role_permissions (role_id, permission_id) "
        "SELECT r.id, p.id FROM roles r CROSS JOIN permissions p "
        "WHERE r.name = 'admin' AND p.name = 'reviews.read' "
        "ON CONFLICT DO NOTHING"
    )


def downgrade() -> None:
    op.execute(
        "DELETE FROM role_permissions WHERE permission_id IN ("
        "SELECT id FROM permissions WHERE name IN "
        "('reviews.read', 'reviews.moderate'))"
    )
    op.execute(
        "DELETE FROM admin_user_permissions WHERE permission_id IN ("
        "SELECT id FROM permissions WHERE name IN "
        "('reviews.read', 'reviews.moderate'))"
    )
    op.execute(
        "DELETE FROM permissions WHERE name IN "
        "('reviews.read', 'reviews.moderate')"
    )