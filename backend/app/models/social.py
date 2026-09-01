"""Social models: user follows and user notifications."""

from datetime import datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class UserFollow(Base):
    __tablename__ = "user_follows"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    follower_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    following_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
    )

    follower = relationship(
        "User",
        foreign_keys=[follower_id],
    )

    following = relationship(
        "User",
        foreign_keys=[following_id],
    )

    __table_args__ = (
        sa.UniqueConstraint(
            "follower_id",
            "following_id",
            name="uq_user_follows_follower_following",
        ),
    )


class UserNotification(Base):
    __tablename__ = "user_notifications"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    # المستخدم صاحب الإشعار (المستقبِل)
    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # المستخدم المُحدِث (مثل من تابع)
    actor_user_id: Mapped[UUID | None] = mapped_column(
        sa.Uuid,
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
    )

    type: Mapped[str] = mapped_column(
        sa.String(50),
        nullable=False,
        default="GENERIC",
        server_default="GENERIC",
        index=True,
    )

    text: Mapped[str] = mapped_column(
        sa.Text,
        nullable=False,
    )

    data: Mapped[dict] = mapped_column(
        sa.JSON,
        nullable=False,
        default=dict,
        server_default=sa.text("'{}'::json"),
    )

    is_read: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=False,
        server_default=sa.text("false"),
        index=True,
    )

    read_at: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
        index=True,
    )

    user = relationship(
        "User",
        foreign_keys=[user_id],
    )

    actor = relationship(
        "User",
        foreign_keys=[actor_user_id],
    )
