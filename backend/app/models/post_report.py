"""Post report model (الإبلاغ عن منشور).

A user who considers a community post abusive / inappropriate can report
it. Reports are kept separate from rating appeals (see ``post_appeal.py``)
so admins can manage the two queues independently.
"""

from datetime import datetime
from enum import Enum
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class ReportCategory(str, Enum):
    """Category of a report.

    Kept as an open-ended enum so new categories can be added without a
    table change.
    """

    ABUSE = "ABUSE"
    INAPPROPRIATE_CONTENT = "INAPPROPRIATE_CONTENT"
    SPAM = "SPAM"
    FALSE_INFO = "FALSE_INFO"
    OTHER = "OTHER"


class ReportStatus(str, Enum):
    """Lifecycle status of a report."""

    PENDING = "PENDING"
    UNDER_REVIEW = "UNDER_REVIEW"
    RESOLVED = "RESOLVED"
    REJECTED = "REJECTED"
    CANCELLED = "CANCELLED"


class ReportPostAction(str, Enum):
    """Decision the admin took on the reported post."""

    NONE = "NONE"
    DELETE_POST = "DELETE_POST"
    HIDE_POST = "HIDE_POST"
    LEAVE_AS_IS = "LEAVE_AS_IS"


class PostReport(Base):
    """A user's report about a community post."""

    __tablename__ = "post_reports"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    post_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "community_posts.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    # The user who filed the report.
    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    category: Mapped[ReportCategory] = mapped_column(
        sa.Enum(
            ReportCategory,
            name="report_category",
            create_constraint=False,
        ),
        nullable=False,
        index=True,
    )

    description: Mapped[str] = mapped_column(
        sa.Text,
        nullable=False,
    )

    status: Mapped[ReportStatus] = mapped_column(
        sa.Enum(
            ReportStatus,
            name="report_status",
            create_constraint=False,
        ),
        nullable=False,
        server_default=ReportStatus.PENDING.value,
        index=True,
    )

    # Internal admin notes (never exposed to the regular user).
    admin_notes: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    # Post decision taken by the admin (independent from the status).
    action_taken: Mapped[ReportPostAction | None] = mapped_column(
        sa.Enum(
            ReportPostAction,
            name="report_post_action",
            create_constraint=False,
        ),
        nullable=True,
    )

    # Admin who reviewed the report. ``admin_users.id`` is an Integer
    # autoincrement PK, so the FK column must be Integer as well (same
    # convention as ``place_contributions.reviewed_by``).
    reviewed_by: Mapped[int | None] = mapped_column(
        sa.Integer,
        sa.ForeignKey(
            "admin_users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    reviewed_at: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
        index=True,
    )

    updated_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        onupdate=sa.func.now(),
        nullable=False,
    )

    post = relationship(
        "CommunityPost",
        back_populates="reports",
    )

    user = relationship(
        "User",
        back_populates="reports",
    )

    reviewer = relationship(
        "AdminUser",
        foreign_keys=[reviewed_by],
    )

    __table_args__ = (
        # One report row per user/post: re-reporting reuses the same row
        # once the previous report is closed (see ModerationService).
        sa.UniqueConstraint(
            "post_id",
            "user_id",
            name="uq_post_reports_post_user",
        ),
    )