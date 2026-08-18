"""Add wallet status and transfer protection."""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "7e4534ba168d"
down_revision = "ac000e8c9184"
branch_labels = None
depends_on = None


wallet_status = sa.Enum(
    "ACTIVE",
    "SUSPENDED",
    "HIDDEN",
    name="wallet_status",
)


def upgrade() -> None:
    wallet_status.create(op.get_bind(), checkfirst=True)

    op.add_column(
        "user_wallets",
        sa.Column(
            "status",
            wallet_status,
            server_default="ACTIVE",
            nullable=False,
        ),
    )

    op.add_column(
        "user_wallets",
        sa.Column(
            "status_reason",
            sa.Text(),
            nullable=True,
        ),
    )

    op.add_column(
        "user_wallets",
        sa.Column(
            "status_changed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    op.add_column(
        "user_wallets",
        sa.Column(
            "status_changed_by",
            sa.Integer(),
            nullable=True,
        ),
    )

    op.add_column(
        "user_wallets",
        sa.Column(
            "suspended_until",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    op.add_column(
        "user_wallets",
        sa.Column(
            "transfers_blocked_until",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    op.add_column(
        "user_wallets",
        sa.Column(
            "transfers_block_reason",
            sa.Text(),
            nullable=True,
        ),
    )

    op.create_index(
        op.f("ix_user_wallets_status"),
        "user_wallets",
        ["status"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_user_wallets_status"),
        table_name="user_wallets",
    )

    op.drop_column(
        "user_wallets",
        "transfers_block_reason",
    )

    op.drop_column(
        "user_wallets",
        "transfers_blocked_until",
    )

    op.drop_column(
        "user_wallets",
        "suspended_until",
    )

    op.drop_column(
        "user_wallets",
        "status_changed_by",
    )

    op.drop_column(
        "user_wallets",
        "status_changed_at",
    )

    op.drop_column(
        "user_wallets",
        "status_reason",
    )

    op.drop_column(
        "user_wallets",
        "status",
    )

    wallet_status.drop(
        op.get_bind(),
        checkfirst=True,
    )