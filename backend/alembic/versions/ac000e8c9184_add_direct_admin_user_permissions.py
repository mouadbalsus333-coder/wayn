"""Add direct admin user permissions.

Revision ID: ac000e8c9184
Revises: 9c4e7a1b2d8f
Create Date: 2026-08-14 07:30:13.767699
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "ac000e8c9184"
down_revision = "9c4e7a1b2d8f"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "admin_user_permissions",
        sa.Column(
            "admin_user_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "permission_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["admin_user_id"],
            ["admin_users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["permission_id"],
            ["permissions.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "admin_user_id",
            "permission_id",
        ),
    )


def downgrade() -> None:
    op.drop_table("admin_user_permissions")
