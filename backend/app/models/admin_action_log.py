"""Admin action log (سجل الإجراءات الإدارية).

Lightweight audit trail for moderation decisions: who reviewed an appeal
or a report, who changed its status and who hid/deleted a post because of
it. Nothing in the project changes moderation state without writing a row
here.
"""

from datetime import datetime
from enum import Enum
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class AdminActionEntity(str, Enum):
    """Entity a logged admin action belongs to."""

    APPEAL = "APPEAL"
    REPORT = "REPORT"
    POST = "POST"


class AdminActionType(str, Enum):
    """Logged admin actions."""

    STATUS_CHANGED = "STATUS_CHANGED"
    NOTE_ADDED = "NOTE_ADDED"
    POST_HIDDEN = "POST_HIDDEN"
    POST_RESTORED = "POST_RESTORED"
    POST_DELETED = "POST_DELETED"
    POST_LEFT_AS_IS = "POST_LEFT_AS_IS"
    POST_PERMANENTLY_DELETED = "POST_PERMANENTLY_DELETED"


class AdminActionLog(Base):
    """A single admin action, kept for accountability."""

    __tablename__ = "admin_action_logs"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    # Snapshot kept so the trail survives admin account deletion.
    admin_email: Mapped[str | None] = mapped_column(
        sa.String(255),
        nullable=True,
    )

    # ``admin_users.id`` is an Integer autoincrement PK, so this FK column
    # must be Integer as well.
    admin_user_id: Mapped[int | None] = mapped_column(
        sa.Integer,
        sa.ForeignKey(
            "admin_users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    entity_type: Mapped[AdminActionEntity] = mapped_column(
        sa.Enum(
            AdminActionEntity,
            name="admin_action_entity",
            create_constraint=False,
        ),
        nullable=False,
        index=True,
    )

    # Polymorphic reference to the affected row (appeal / report / post).
    entity_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        nullable=False,
        index=True,
    )

    action: Mapped[AdminActionType] = mapped_column(
        sa.Enum(
            AdminActionType,
            name="admin_action_type",
            create_constraint=False,
        ),
        nullable=False,
        index=True,
    )

    notes: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
        index=True,
    )

    admin_user = relationship(
        "AdminUser",
        foreign_keys=[admin_user_id],
    )