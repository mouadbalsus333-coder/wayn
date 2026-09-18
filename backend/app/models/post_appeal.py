"""Post appeal model (طعن في التقييم).

A user who believes the rating attached to a community post is wrong can
file an appeal. The appeal goes through an admin review lifecycle and is
kept separately from post reports (see ``post_report.py``).
"""

from datetime import datetime
from enum import Enum
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class AppealType(str, Enum):
    """Types of appeals a user can file.

    The enum is intentionally open-ended so new appeal types can be added
    without changing the table structure.
    """

    INCORRECT_RATING = "INCORRECT_RATING"
    MISLEADING_RATING = "MISLEADING_RATING"
    OTHER = "OTHER"


class AppealStatus(str, Enum):
    """Lifecycle status of an appeal."""

    PENDING = "PENDING"
    UNDER_REVIEW = "UNDER_REVIEW"
    RESOLVED = "RESOLVED"
    REJECTED = "REJECTED"
    CANCELLED = "CANCELLED"


class AppealPostAction(str, Enum):
    """Decision the admin took on the post after reviewing the appeal."""

    NONE = "NONE"
    DELETE_POST = "DELETE_POST"
    HIDE_POST = "HIDE_POST"
    LEAVE_AS_IS = "LEAVE_AS_IS"


class PostAppeal(Base):
    """A user's appeal against the rating of a community post."""

    __tablename__ = "post_appeals"

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

    # The user who filed the appeal.
    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    type: Mapped[AppealType] = mapped_column(
        sa.Enum(
            AppealType,
            name="appeal_type",
            create_constraint=False,
        ),
        nullable=False,
        index=True,
    )

    reason: Mapped[str] = mapped_column(
        sa.Text,
        nullable=False,
    )

    status: Mapped[AppealStatus] = mapped_column(
        sa.Enum(
            AppealStatus,
            name="appeal_status",
            create_constraint=False,
        ),
        nullable=False,
        server_default=AppealStatus.PENDING.value,
        index=True,
    )

    # Internal admin notes (never exposed to the regular user).
    admin_notes: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    # Post decision taken by the admin (independent from the status).
    action_taken: Mapped[AppealPostAction | None] = mapped_column(
        sa.Enum(
            AppealPostAction,
            name="appeal_post_action",
            create_constraint=False,
        ),
        nullable=True,
    )

    # Admin who reviewed the appeal. ``admin_users.id`` is an Integer
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
        back_populates="appeals",
    )

    user = relationship(
        "User",
        back_populates="appeals",
    )

    reviewer = relationship(
        "AdminUser",
        foreign_keys=[reviewed_by],
    )

    __table_args__ = (
        # One appeal row per user/post: re-appealing reuses the same row
        # once the previous appeal is closed (see ModerationService).
        sa.UniqueConstraint(
            "post_id",
            "user_id",
            name="uq_post_appeals_post_user",
        ),
    )