"""Add users table.

Revision ID: 0085d26d3b57
Revises: 684cfb14e6e5
Create Date: 2026-08-09 00:04:59.848228
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = "0085d26d3b57"
down_revision = "684cfb14e6e5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create the users table."""

    op.create_table(
        "users",

        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            nullable=False,
            server_default=sa.text("gen_random_uuid()"),
        ),

        sa.Column(
            "email",
            sa.String(length=320),
            nullable=False,
        ),

        sa.Column(
            "password_hash",
            sa.String(length=255),
            nullable=False,
        ),

        sa.Column(
            "full_name",
            sa.String(length=255),
            nullable=False,
        ),

        sa.Column(
            "username",
            sa.String(length=50),
            nullable=False,
        ),

        sa.Column(
            "phone",
            sa.String(length=32),
            nullable=True,
        ),

        sa.Column(
            "avatar_url",
            sa.String(length=1024),
            nullable=True,
        ),

        sa.Column(
            "bio",
            sa.Text(),
            nullable=True,
        ),

        sa.Column(
            "city",
            sa.String(length=255),
            nullable=True,
        ),

        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),

        sa.Column(
            "is_verified",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),

        sa.Column(
            "last_login_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),

        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),

        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),

        sa.PrimaryKeyConstraint("id"),
    )

    # Unique indexes
    op.create_index(
        "ix_users_email",
        "users",
        ["email"],
        unique=True,
    )

    op.create_index(
        "ix_users_username",
        "users",
        ["username"],
        unique=True,
    )

    op.create_index(
        "ix_users_phone",
        "users",
        ["phone"],
        unique=True,
    )


def downgrade() -> None:
    """Remove the users table."""

    # Drop indexes safely.
    # IF EXISTS prevents downgrade from failing if an index
    # was already removed manually or does not exist.

    op.execute(
        "DROP INDEX IF EXISTS ix_users_phone"
    )

    op.execute(
        "DROP INDEX IF EXISTS ix_users_username"
    )

    op.execute(
        "DROP INDEX IF EXISTS ix_users_email"
    )

    # Remove the users table safely.
    op.execute(
        "DROP TABLE IF EXISTS users"
    )
