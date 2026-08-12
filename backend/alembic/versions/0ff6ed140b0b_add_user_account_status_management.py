"""Add user account status management.

Revision ID: 0ff6ed140b0b
Revises: 16e6d2c732aa
Create Date: 2026-08-09 07:45:10.531004
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = "0ff6ed140b0b"
down_revision = "16e6d2c732aa"
branch_labels = None
depends_on = None


account_status_enum = postgresql.ENUM(
    "ACTIVE",
    "HIDDEN",
    "SUSPENDED",
    "BANNED",
    name="account_status",
    create_type=False,
)


def upgrade() -> None:
    # ============================================================
    # 1. Create PostgreSQL ENUM type
    # ============================================================

    account_status_enum.create(
        op.get_bind(),
        checkfirst=True,
    )

    # ============================================================
    # 2. Add account status
    # ============================================================

    op.add_column(
        "users",
        sa.Column(
            "account_status",
            account_status_enum,
            nullable=False,
            server_default="ACTIVE",
        ),
    )

    # ============================================================
    # 3. Status metadata
    # ============================================================

    op.add_column(
        "users",
        sa.Column(
            "status_reason",
            sa.Text(),
            nullable=True,
        ),
    )

    op.add_column(
        "users",
        sa.Column(
            "status_changed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    op.add_column(
        "users",
        sa.Column(
            "status_changed_by",
            sa.Integer(),
            nullable=True,
        ),
    )

    op.add_column(
        "users",
        sa.Column(
            "suspended_until",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    # ============================================================
    # 4. Authentication invalidation
    # ============================================================

    op.add_column(
        "users",
        sa.Column(
            "token_version",
            sa.Integer(),
            nullable=False,
            server_default="1",
        ),
    )

    # ============================================================
    # 5. Index
    # ============================================================

    op.create_index(
        "ix_users_account_status",
        "users",
        ["account_status"],
        unique=False,
    )


def downgrade() -> None:
    # ============================================================
    # 1. Remove index
    # ============================================================

    op.drop_index(
        "ix_users_account_status",
        table_name="users",
    )

    # ============================================================
    # 2. Remove columns
    # ============================================================

    op.drop_column(
        "users",
        "token_version",
    )

    op.drop_column(
        "users",
        "suspended_until",
    )

    op.drop_column(
        "users",
        "status_changed_by",
    )

    op.drop_column(
        "users",
        "status_changed_at",
    )

    op.drop_column(
        "users",
        "status_reason",
    )

    op.drop_column(
        "users",
        "account_status",
    )

    # ============================================================
    # 3. Remove PostgreSQL ENUM
    # ============================================================

    account_status_enum.drop(
        op.get_bind(),
        checkfirst=True,
    )
