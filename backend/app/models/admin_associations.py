import sqlalchemy as sa

from app.database.base import Base


admin_user_roles = sa.Table(
    "admin_user_roles",
    Base.metadata,
    sa.Column(
        "admin_user_id",
        sa.Integer,
        sa.ForeignKey(
            "admin_users.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    ),
    sa.Column(
        "role_id",
        sa.Integer,
        sa.ForeignKey(
            "roles.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    ),
)


admin_user_permissions = sa.Table(
    "admin_user_permissions",
    Base.metadata,
    sa.Column(
        "admin_user_id",
        sa.Integer,
        sa.ForeignKey(
            "admin_users.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    ),
    sa.Column(
        "permission_id",
        sa.Integer,
        sa.ForeignKey(
            "permissions.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    ),
)


role_permissions = sa.Table(
    "role_permissions",
    Base.metadata,
    sa.Column(
        "role_id",
        sa.Integer,
        sa.ForeignKey(
            "roles.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    ),
    sa.Column(
        "permission_id",
        sa.Integer,
        sa.ForeignKey(
            "permissions.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    ),
)