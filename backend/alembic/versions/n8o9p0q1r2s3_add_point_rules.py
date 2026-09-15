"""Add point_rules table, seed default tasks and points.manage permission.

Revision ID: n8o9p0q1r2s3
Revises: m7n8o9p0q1r2
Create Date: 2026-09-14 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "n8o9p0q1r2s3"
down_revision = "m7n8o9p0q1r2"
branch_labels = None
depends_on = None


SUPER_ADMIN_ROLE = "super_admin"

DEFAULT_RULES = [
    # (action_key, points, title, description, is_active)
    ("add_place", 400, "أضف مكانًا جديدًا", "ساعدنا في إضافة أماكن جديدة إلى WAYN", True),
    ("update_place", 100, "عدّل مكانًا", "حسّن بيانات مكان موجود في WAYN", False),
    ("add_image", 50, "أضف صورة لمكان", "أضف صورة حقيقية لمكان موجود", False),
    ("report_error", 50, "أبلغ عن خطأ", "ساعدنا في تصحيح المعلومات الخاطئة", False),
    ("send_feedback", 25, "أرسل اقتراحًا", "شاركنا اقتراحاتك لتحسين WAYN", False),
]


def upgrade() -> None:
    op.create_table(
        "point_rules",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("action_key", sa.String(length=100), nullable=False),
        sa.Column("points", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("description", sa.String(length=255), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("requires_approval", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("limit_per_user", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_point_rules_action_key"), "point_rules", ["action_key"], unique=True)
    op.create_index(op.f("ix_point_rules_is_active"), "point_rules", ["is_active"], unique=False)

    for action_key, points, title, description, is_active in DEFAULT_RULES:
        op.execute(
            "INSERT INTO point_rules (action_key, points, title, description, is_active) "
            f"VALUES ('{action_key}', {points}, '{title}', '{description}', "
            f"{'true' if is_active else 'false'}) "
            "ON CONFLICT (action_key) DO NOTHING"
        )

    op.execute(
        "INSERT INTO permissions (name, description) "
        "VALUES ('points.manage', 'Manage point rules and reward values') "
        "ON CONFLICT (name) DO NOTHING"
    )
    op.execute(
        "DELETE FROM admin_user_permissions "
        "WHERE permission_id IN ("
        "SELECT id FROM permissions WHERE name = 'points.manage')"
    )
    op.execute(
        "DELETE FROM role_permissions "
        "WHERE permission_id IN ("
        "SELECT id FROM permissions WHERE name = 'points.manage') "
        "AND role_id NOT IN ("
        f"SELECT id FROM roles WHERE name = '{SUPER_ADMIN_ROLE}')"
    )
    op.execute(
        "INSERT INTO role_permissions (role_id, permission_id) "
        "SELECT r.id, p.id FROM roles r, permissions p "
        "WHERE r.name = '" + SUPER_ADMIN_ROLE + "' "
        "AND p.name = 'points.manage' "
        "ON CONFLICT DO NOTHING"
    )


def downgrade() -> None:
    op.execute(
        "DELETE FROM admin_user_permissions "
        "WHERE permission_id IN ("
        "SELECT id FROM permissions WHERE name = 'points.manage')"
    )
    op.execute(
        "DELETE FROM role_permissions "
        "WHERE permission_id IN ("
        "SELECT id FROM permissions WHERE name = 'points.manage')"
    )
    op.execute("DELETE FROM permissions WHERE name = 'points.manage'")
    op.drop_index(op.f("ix_point_rules_is_active"), table_name="point_rules")
    op.drop_index(op.f("ix_point_rules_action_key"), table_name="point_rules")
    op.drop_table("point_rules")
