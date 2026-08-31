"""Add user verification codes for email verification and password reset."""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "b91f2c7d8e31"
down_revision = "7e4534ba168d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_verification_codes",
        sa.Column(
            "id",
            sa.BigInteger(),
            autoincrement=True,
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "purpose",
            sa.String(length=32),
            nullable=False,
        ),
        sa.Column(
            "code_hash",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "expires_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "attempts",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "used_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        op.f("ix_user_verification_codes_user_id"),
        "user_verification_codes",
        ["user_id"],
        unique=False,
    )

    op.create_index(
        op.f("ix_user_verification_codes_purpose"),
        "user_verification_codes",
        ["purpose"],
        unique=False,
    )

    op.create_index(
        op.f("ix_user_verification_codes_expires_at"),
        "user_verification_codes",
        ["expires_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_user_verification_codes_expires_at"),
        table_name="user_verification_codes",
    )

    op.drop_index(
        op.f("ix_user_verification_codes_purpose"),
        table_name="user_verification_codes",
    )

    op.drop_index(
        op.f("ix_user_verification_codes_user_id"),
        table_name="user_verification_codes",
    )

    op.drop_table("user_verification_codes")