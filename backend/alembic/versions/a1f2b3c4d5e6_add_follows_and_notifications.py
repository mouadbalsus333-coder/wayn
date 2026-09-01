"""Add user follows and user notifications.

Revision ID: a1f2b3c4d5e6
Revises: e2b15b5f296d
Create Date: 2026-09-01 12:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "a1f2b3c4d5e6"
down_revision = "e2b15b5f296d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ============================================================
    # User follows
    # ============================================================

    op.create_table(
        "user_follows",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column(
            "follower_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "following_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "follower_id",
            "following_id",
            name="uq_user_follows_follower_following",
        ),
    )

    op.create_index(
        op.f("ix_user_follows_follower_id"),
        "user_follows",
        ["follower_id"],
        unique=False,
    )

    op.create_index(
        op.f("ix_user_follows_following_id"),
        "user_follows",
        ["following_id"],
        unique=False,
    )

    # ============================================================
    # User notifications
    # ============================================================

    op.create_table(
        "user_notifications",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column(
            "user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "actor_user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=True,
        ),
        sa.Column(
            "type",
            sa.String(50),
            server_default="GENERIC",
            nullable=False,
        ),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column(
            "data",
            sa.JSON(),
            server_default=sa.text("'{}'::json"),
            nullable=False,
        ),
        sa.Column(
            "is_read",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
        sa.Column(
            "read_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        op.f("ix_user_notifications_user_id"),
        "user_notifications",
        ["user_id"],
        unique=False,
    )

    op.create_index(
        op.f("ix_user_notifications_type"),
        "user_notifications",
        ["type"],
        unique=False,
    )

    op.create_index(
        op.f("ix_user_notifications_is_read"),
        "user_notifications",
        ["is_read"],
        unique=False,
    )

    op.create_index(
        op.f("ix_user_notifications_created_at"),
        "user_notifications",
        ["created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_user_notifications_created_at"),
        table_name="user_notifications",
    )
    op.drop_index(
        op.f("ix_user_notifications_is_read"),
        table_name="user_notifications",
    )
    op.drop_index(
        op.f("ix_user_notifications_type"),
        table_name="user_notifications",
    )
    op.drop_index(
        op.f("ix_user_notifications_user_id"),
        table_name="user_notifications",
    )
    op.drop_table("user_notifications")

    op.drop_index(
        op.f("ix_user_follows_following_id"),
        table_name="user_follows",
    )
    op.drop_index(
        op.f("ix_user_follows_follower_id"),
        table_name="user_follows",
    )
    op.drop_table("user_follows")
