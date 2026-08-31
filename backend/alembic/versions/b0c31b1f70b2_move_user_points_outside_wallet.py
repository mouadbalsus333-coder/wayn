"""Move user points outside wallet."""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "b0c31b1f70b2"
down_revision = "b91f2c7d8e31"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ============================================================
    # 1. Add points to users
    # ============================================================

    op.add_column(
        "users",
        sa.Column(
            "points",
            sa.BigInteger(),
            server_default="0",
            nullable=False,
        ),
    )

    # ============================================================
    # 2. Migrate existing wallet points to the user
    # ============================================================
    #
    # Every user has at most one wallet.
    # Existing points must not be lost.
    #
    # COALESCE protects against unexpected NULL values.
    #

    op.execute(
        sa.text(
            """
            UPDATE users
            SET points = COALESCE(user_wallets.points_balance, 0)
            FROM user_wallets
            WHERE user_wallets.user_id = users.id
            """
        )
    )

    # ============================================================
    # 3. Remove points from wallets
    # ============================================================

    op.drop_column(
        "user_wallets",
        "points_balance",
    )

    # ============================================================
    # 4. Prevent negative user points
    # ============================================================

    op.create_check_constraint(
        "ck_users_points_non_negative",
        "users",
        "points >= 0",
    )


def downgrade() -> None:
    # ============================================================
    # 1. Restore points_balance to wallets
    # ============================================================

    op.add_column(
        "user_wallets",
        sa.Column(
            "points_balance",
            sa.BigInteger(),
            server_default="0",
            nullable=False,
        ),
    )

    # ============================================================
    # 2. Move user points back into their wallets
    # ============================================================

    op.execute(
        sa.text(
            """
            UPDATE user_wallets
            SET points_balance = COALESCE(users.points, 0)
            FROM users
            WHERE users.id = user_wallets.user_id
            """
        )
    )

    # ============================================================
    # 3. Remove the user points constraint
    # ============================================================

    op.drop_constraint(
        "ck_users_points_non_negative",
        "users",
        type_="check",
    )

    # ============================================================
    # 4. Remove points from users
    # ============================================================

    op.drop_column(
        "users",
        "points",
    )