"""Add user_devices, admin_notifications tables, user_notifications.source column, and notification permissions.

Revision ID: m7n8o9p0q1r2
Revises: l1m2n3o4p5q6
Create Date: 2026-09-12

"""

from typing import Sequence, Union

from alembic import op
from sqlalchemy.dialects import postgresql
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "m7n8o9p0q1r2"
down_revision: Union[str, Sequence[str], None] = "l1m2n3o4p5q6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# ============================================================
# Permissions to add
# ============================================================
NEW_PERMISSIONS = {
    "notifications.read": "Read admin notifications list and detail",
    "notifications.send": "Send admin notifications",
}


def upgrade() -> None:
    # ============================================================
    # 1. Table: user_devices
    # ============================================================
    op.create_table(
        "user_devices",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=False),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
            primary_key=True,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=False),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "device_id",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "fcm_token",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "platform",
            sa.String(length=20),
            nullable=False,
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "user_id",
            "device_id",
            name="uq_user_devices_user_device",
        ),
    )

    op.create_index(
        "ix_user_devices_fcm_token",
        "user_devices",
        ["fcm_token"],
    )
    op.create_index(
        "ix_user_devices_is_active",
        "user_devices",
        ["is_active"],
    )

    # ============================================================
    # 2. Table: admin_notifications
    #
    # Notes:
    # - channel / notification_type / status are stored as
    #   sa.String (matching the model). No PostgreSQL ENUM is
    #   created because the SQLAlchemy model defines those
    #   columns as plain String columns.
    # ============================================================
    op.create_table(
        "admin_notifications",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=False),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
            primary_key=True,
        ),
        sa.Column(
            "title",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "body",
            sa.Text(),
            nullable=False,
        ),
        sa.Column(
            "channel",
            sa.String(length=20),
            server_default=sa.text("'both'"),
            nullable=False,
        ),
        sa.Column(
            "notification_type",
            sa.String(length=50),
            server_default=sa.text("'broadcast'"),
            nullable=False,
        ),
        sa.Column(
            "sent_by_admin_id",
            sa.Integer(),
            sa.ForeignKey("admin_users.id", ondelete="CASCADE"),
            nullable=False,
            # NOTE: no index=True here - the explicit op.create_index
            # below ("ix_admin_notifications_sent_by") handles it.
            # Using index=True would make create_table auto-generate
            # an index and conflict with the explicit one.
        ),
        sa.Column(
            "total_recipients",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "delivered_count",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "failed_count",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.String(length=30),
            server_default=sa.text("'pending'"),
            nullable=False,
            # NOTE: no index=True here - the explicit op.create_index
            # below ("ix_admin_notifications_status") handles it.
            # This was the root cause of the DuplicateTableError:
            # create_table auto-created ix_admin_notifications_status,
            # then op.create_index tried to create it again.
        ),
        sa.Column(
            "scheduled_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "sent_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )

    op.create_index(
        "ix_admin_notifications_status",
        "admin_notifications",
        ["status"],
    )
    op.create_index(
        "ix_admin_notifications_sent_by",
        "admin_notifications",
        ["sent_by_admin_id"],
    )
    op.create_index(
        "ix_admin_notifications_created_at",
        "admin_notifications",
        ["created_at"],
    )

    # ============================================================
    # 3. Column: user_notifications.source
    #
    # The model defines this column as nullable=False with
    # default="social" and server_default="social".
    # We add it with a server_default so that EXISTING rows
    # get the value 'social' automatically and the NOT NULL
    # constraint never conflicts with legacy data.
    # ============================================================
    op.add_column(
        "user_notifications",
        sa.Column(
            "source",
            sa.String(length=50),
            server_default=sa.text("'social'"),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_user_notifications_source",
        "user_notifications",
        ["source"],
    )

    # ============================================================
    # 4. Permissions: notifications.read, notifications.send
    #
    # Pattern matches the existing review/wallet permission
    # migrations: insert if not exists, then grant to roles.
    # ============================================================
    for name, description in NEW_PERMISSIONS.items():
        op.execute(
            "INSERT INTO permissions (name, description) "
            f"VALUES ('{name}', '{description}') "
            "ON CONFLICT (name) DO NOTHING"
        )

    op.execute(
        "INSERT INTO role_permissions (role_id, permission_id) "
        "SELECT r.id, p.id FROM roles r CROSS JOIN permissions p "
        "WHERE r.name = 'super_admin' "
        "AND p.name IN ('notifications.read', 'notifications.send') "
        "ON CONFLICT DO NOTHING"
    )
    op.execute(
        "INSERT INTO role_permissions (role_id, permission_id) "
        "SELECT r.id, p.id FROM roles r CROSS JOIN permissions p "
        "WHERE r.name = 'admin' "
        "AND p.name IN ('notifications.read', 'notifications.send') "
        "ON CONFLICT DO NOTHING"
    )



def downgrade() -> None:
    # ============================================================
    # Reverse permissions
    # ============================================================
    op.execute(
        "DELETE FROM role_permissions WHERE permission_id IN ("
        "SELECT id FROM permissions WHERE name IN "
        "('notifications.read', 'notifications.send'))"
    )
    op.execute(
        "DELETE FROM admin_user_permissions WHERE permission_id IN ("
        "SELECT id FROM permissions WHERE name IN "
        "('notifications.read', 'notifications.send'))"
    )
    op.execute(
        "DELETE FROM permissions WHERE name IN "
        "('notifications.read', 'notifications.send')"
    )

    # ============================================================
    # Reverse: user_notifications.source
    # ============================================================
    op.drop_index(
        "ix_user_notifications_source",
        table_name="user_notifications",
    )
    op.drop_column("user_notifications", "source")

    # ============================================================
    # Reverse: admin_notifications
    # ============================================================
    op.drop_index(
        "ix_admin_notifications_created_at",
        table_name="admin_notifications",
    )
    op.drop_index(
        "ix_admin_notifications_sent_by",
        table_name="admin_notifications",
    )
    op.drop_index(
        "ix_admin_notifications_status",
        table_name="admin_notifications",
    )
    op.drop_table("admin_notifications")

    # ============================================================
    # Reverse: user_devices
    # ============================================================
    op.drop_index(
        "ix_user_devices_is_active",
        table_name="user_devices",
    )
    op.drop_index(
        "ix_user_devices_fcm_token",
        table_name="user_devices",
    )
    op.drop_table("user_devices")
