"""Add moderation tables (appeals, reports, admin action log)

Creates:
- post_appeals: الطعن في التقييم (rating appeals) lifecycle
- post_reports: الإبلاغ عن منشور (post reports) lifecycle
- admin_action_logs: سجل الإجراءات الإدارية (admin audit trail)

Also guarantees the moderation permissions exist in the catalog:
- appeals.read / appeals.manage
- reports.read / reports.write / reports.resolve

Revision ID: o1p2q3r4s5t6
Revises: a1b2c3d4e5f6
Create Date: 2026-09-17
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ENUM as PG_ENUM


# revision identifiers
revision = "o1p2q3r4s5t6"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None


APPEAL_PERMISSIONS = {
    "appeals.read": "View rating appeals",
    "appeals.manage": "Review and resolve rating appeals",
}

REPORT_PERMISSIONS = {
    "reports.read": "View reports",
    "reports.write": "Handle reports",
    "reports.resolve": "Resolve reports",
}


# Keep track of enum types that are created by THIS migration.
# This prevents downgrade() from deleting enums that existed before
# this migration was applied.
_created_enum_types: list[str] = []


def _ensure_enum(name: str, values: list[str]) -> None:
    """Create a PostgreSQL enum type only when it does not already exist."""

    joined = ", ".join(f"'{value}'" for value in values)

    bind = op.get_bind()

    exists = bind.execute(
        sa.text(
            """
            SELECT EXISTS (
                SELECT 1
                FROM pg_type
                WHERE typname = :name
                  AND typtype = 'e'
            )
            """
        ),
        {"name": name},
    ).scalar()

    if exists:
        return

    op.execute(
        sa.text(
            f"""
            CREATE TYPE {name} AS ENUM ({joined})
            """
        )
    )

    _created_enum_types.append(name)


def upgrade() -> None:
    # ============================================================
    # Enum types
    # ============================================================

    _ensure_enum(
        "appeal_type",
        [
            "INCORRECT_RATING",
            "MISLEADING_RATING",
            "OTHER",
        ],
    )

    _ensure_enum(
        "appeal_status",
        [
            "PENDING",
            "UNDER_REVIEW",
            "RESOLVED",
            "REJECTED",
            "CANCELLED",
        ],
    )

    _ensure_enum(
        "appeal_post_action",
        [
            "NONE",
            "DELETE_POST",
            "HIDE_POST",
            "LEAVE_AS_IS",
        ],
    )

    _ensure_enum(
        "report_category",
        [
            "ABUSE",
            "INAPPROPRIATE_CONTENT",
            "SPAM",
            "FALSE_INFO",
            "OTHER",
        ],
    )

    _ensure_enum(
        "report_status",
        [
            "PENDING",
            "UNDER_REVIEW",
            "RESOLVED",
            "REJECTED",
            "CANCELLED",
        ],
    )

    _ensure_enum(
        "report_post_action",
        [
            "NONE",
            "DELETE_POST",
            "HIDE_POST",
            "LEAVE_AS_IS",
        ],
    )

    _ensure_enum(
        "admin_action_entity",
        [
            "APPEAL",
            "REPORT",
            "POST",
        ],
    )

    _ensure_enum(
        "admin_action_type",
        [
            "STATUS_CHANGED",
            "NOTE_ADDED",
            "POST_HIDDEN",
            "POST_RESTORED",
            "POST_DELETED",
            "POST_LEFT_AS_IS",
            "POST_PERMANENTLY_DELETED",
        ],
    )

    # ============================================================
    # post_appeals
    # ============================================================

    op.create_table(
        "post_appeals",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "post_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "type",
            PG_ENUM(
                "INCORRECT_RATING",
                "MISLEADING_RATING",
                "OTHER",
                name="appeal_type",
                create_type=False,
            ),
            nullable=False,
        ),
        sa.Column(
            "reason",
            sa.Text(),
            nullable=False,
        ),
        sa.Column(
            "status",
            PG_ENUM(
                "PENDING",
                "UNDER_REVIEW",
                "RESOLVED",
                "REJECTED",
                "CANCELLED",
                name="appeal_status",
                create_type=False,
            ),
            server_default="PENDING",
            nullable=False,
        ),
        sa.Column(
            "admin_notes",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "action_taken",
            PG_ENUM(
                "NONE",
                "DELETE_POST",
                "HIDE_POST",
                "LEAVE_AS_IS",
                name="appeal_post_action",
                create_type=False,
            ),
            nullable=True,
        ),
        # admin_users.id is an Integer autoincrement primary key (see
        # place_contributions.reviewed_by / wallet_admin_recharge.admin_id),
        # so the reviewer FK must be Integer as well.
        sa.Column(
            "reviewed_by",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "reviewed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["post_id"],
            ["community_posts.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["reviewed_by"],
            ["admin_users.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "post_id",
            "user_id",
            name="uq_post_appeals_post_user",
        ),
    )

    op.create_index(
        "ix_post_appeals_post_id",
        "post_appeals",
        ["post_id"],
    )
    op.create_index(
        "ix_post_appeals_user_id",
        "post_appeals",
        ["user_id"],
    )
    op.create_index(
        "ix_post_appeals_type",
        "post_appeals",
        ["type"],
    )
    op.create_index(
        "ix_post_appeals_status",
        "post_appeals",
        ["status"],
    )
    op.create_index(
        "ix_post_appeals_reviewed_by",
        "post_appeals",
        ["reviewed_by"],
    )
    op.create_index(
        "ix_post_appeals_created_at",
        "post_appeals",
        ["created_at"],
    )

    # ============================================================
    # post_reports
    # ============================================================

    op.create_table(
        "post_reports",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "post_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "category",
            PG_ENUM(
                "ABUSE",
                "INAPPROPRIATE_CONTENT",
                "SPAM",
                "FALSE_INFO",
                "OTHER",
                name="report_category",
                create_type=False,
            ),
            nullable=False,
        ),
        sa.Column(
            "description",
            sa.Text(),
            nullable=False,
        ),
        sa.Column(
            "status",
            PG_ENUM(
                "PENDING",
                "UNDER_REVIEW",
                "RESOLVED",
                "REJECTED",
                "CANCELLED",
                name="report_status",
                create_type=False,
            ),
            server_default="PENDING",
            nullable=False,
        ),
        sa.Column(
            "admin_notes",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "action_taken",
            PG_ENUM(
                "NONE",
                "DELETE_POST",
                "HIDE_POST",
                "LEAVE_AS_IS",
                name="report_post_action",
                create_type=False,
            ),
            nullable=True,
        ),
        # admin_users.id is an Integer autoincrement primary key, so the
        # reviewer FK must be Integer as well (matches post_appeals).
        sa.Column(
            "reviewed_by",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "reviewed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["post_id"],
            ["community_posts.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["reviewed_by"],
            ["admin_users.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "post_id",
            "user_id",
            name="uq_post_reports_post_user",
        ),
    )

    op.create_index(
        "ix_post_reports_post_id",
        "post_reports",
        ["post_id"],
    )
    op.create_index(
        "ix_post_reports_user_id",
        "post_reports",
        ["user_id"],
    )
    op.create_index(
        "ix_post_reports_category",
        "post_reports",
        ["category"],
    )
    op.create_index(
        "ix_post_reports_status",
        "post_reports",
        ["status"],
    )
    op.create_index(
        "ix_post_reports_reviewed_by",
        "post_reports",
        ["reviewed_by"],
    )
    op.create_index(
        "ix_post_reports_created_at",
        "post_reports",
        ["created_at"],
    )

    # ============================================================
    # admin_action_logs
    # ============================================================

    op.create_table(
        "admin_action_logs",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "admin_email",
            sa.String(length=255),
            nullable=True,
        ),
        # FK to admin_users.id which is an Integer autoincrement PK.
        sa.Column(
            "admin_user_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "entity_type",
            PG_ENUM(
                "APPEAL",
                "REPORT",
                "POST",
                name="admin_action_entity",
                create_type=False,
            ),
            nullable=False,
        ),
        sa.Column(
            "entity_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "action",
            PG_ENUM(
                "STATUS_CHANGED",
                "NOTE_ADDED",
                "POST_HIDDEN",
                "POST_RESTORED",
                "POST_DELETED",
                "POST_LEFT_AS_IS",
                "POST_PERMANENTLY_DELETED",
                name="admin_action_type",
                create_type=False,
            ),
            nullable=False,
        ),
        sa.Column(
            "notes",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["admin_user_id"],
            ["admin_users.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_admin_action_logs_admin_user_id",
        "admin_action_logs",
        ["admin_user_id"],
    )
    op.create_index(
        "ix_admin_action_logs_entity_type",
        "admin_action_logs",
        ["entity_type"],
    )
    op.create_index(
        "ix_admin_action_logs_entity_id",
        "admin_action_logs",
        ["entity_id"],
    )
    op.create_index(
        "ix_admin_action_logs_action",
        "admin_action_logs",
        ["action"],
    )
    op.create_index(
        "ix_admin_action_logs_created_at",
        "admin_action_logs",
        ["created_at"],
    )

    # ============================================================
    # Permissions
    # ============================================================

    permissions = {
        **APPEAL_PERMISSIONS,
        **REPORT_PERMISSIONS,
    }

    for name, description in permissions.items():
        op.execute(
            sa.text(
                """
                INSERT INTO permissions (name, description)
                VALUES (:name, :description)
                ON CONFLICT (name) DO NOTHING
                """
            ).bindparams(
                name=name,
                description=description,
            )
        )

    names = ", ".join(
        f"'{name}'" for name in permissions
    )

    # super_admin + moderator get the full moderation set
    op.execute(
        f"""
        INSERT INTO role_permissions (role_id, permission_id)
        SELECT r.id, p.id
        FROM roles r
        CROSS JOIN permissions p
        WHERE r.name IN ('super_admin', 'moderator')
          AND p.name IN ({names})
        ON CONFLICT DO NOTHING
        """
    )

    # plain admins can read both queues
    op.execute(
        """
        INSERT INTO role_permissions (role_id, permission_id)
        SELECT r.id, p.id
        FROM roles r
        CROSS JOIN permissions p
        WHERE r.name = 'admin'
          AND p.name IN ('appeals.read', 'reports.read')
        ON CONFLICT DO NOTHING
        """
    )


def downgrade() -> None:
    # ============================================================
    # Permissions
    # ============================================================

    all_names = ", ".join(
        f"'{name}'"
        for name in {
            **APPEAL_PERMISSIONS,
            **REPORT_PERMISSIONS,
        }
    )

    appeal_names = ", ".join(
        f"'{name}'"
        for name in APPEAL_PERMISSIONS
    )

    op.execute(
        """
        DELETE FROM role_permissions
        WHERE permission_id IN (
            SELECT id
            FROM permissions
            WHERE name IN (
        """
        + all_names
        + """
            )
        )
        """
    )

    op.execute(
        """
        DELETE FROM admin_user_permissions
        WHERE permission_id IN (
            SELECT id
            FROM permissions
            WHERE name IN (
        """
        + all_names
        + """
            )
        )
        """
    )

    # reports.* belong to the base admin catalog,
    # so only appeal permissions introduced here are removed.
    op.execute(
        """
        DELETE FROM permissions
        WHERE name IN (
        """
        + appeal_names
        + """
        )
        """
    )

    # ============================================================
    # admin_action_logs
    # ============================================================

    for index_name in (
        "ix_admin_action_logs_created_at",
        "ix_admin_action_logs_action",
        "ix_admin_action_logs_entity_id",
        "ix_admin_action_logs_entity_type",
        "ix_admin_action_logs_admin_user_id",
    ):
        op.drop_index(
            index_name,
            table_name="admin_action_logs",
        )

    op.drop_table("admin_action_logs")

    # ============================================================
    # post_reports
    # ============================================================

    for index_name in (
        "ix_post_reports_created_at",
        "ix_post_reports_reviewed_by",
        "ix_post_reports_status",
        "ix_post_reports_category",
        "ix_post_reports_user_id",
        "ix_post_reports_post_id",
    ):
        op.drop_index(
            index_name,
            table_name="post_reports",
        )

    op.drop_table("post_reports")

    # ============================================================
    # post_appeals
    # ============================================================

    for index_name in (
        "ix_post_appeals_created_at",
        "ix_post_appeals_reviewed_by",
        "ix_post_appeals_status",
        "ix_post_appeals_type",
        "ix_post_appeals_user_id",
        "ix_post_appeals_post_id",
    ):
        op.drop_index(
            index_name,
            table_name="post_appeals",
        )

    op.drop_table("post_appeals")

    # ============================================================
    # Enum types
    # ============================================================

    # Only remove enum types that were actually created by this
    # migration. Existing/shared enum types must remain untouched.
    for type_name in reversed(_created_enum_types):
        op.execute(
            sa.text(
                f"DROP TYPE IF EXISTS {type_name}"
            )
        )