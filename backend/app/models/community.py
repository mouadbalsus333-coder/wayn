"""Community models for user-generated place experiences."""

from datetime import datetime
from decimal import Decimal
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class CommunityPost(Base):
    __tablename__ = "community_posts"

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    place_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "places.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    text: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    image_url: Mapped[str | None] = mapped_column(
        sa.String(1024),
        nullable=True,
    )

    rating: Mapped[Decimal | None] = mapped_column(
        sa.Numeric(2, 1),
        nullable=True,
    )

    is_visible: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=True,
        server_default=sa.true(),
        index=True,
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

    user = relationship(
        "User",
        back_populates="community_posts",
    )

    place = relationship(
        "Place",
        back_populates="community_posts",
    )

    likes = relationship(
        "CommunityPostLike",
        back_populates="post",
        cascade="all, delete-orphan",
    )

    saves = relationship(
        "CommunityPostSave",
        back_populates="post",
        cascade="all, delete-orphan",
    )

    comments = relationship(
        "CommunityComment",
        back_populates="post",
        cascade="all, delete-orphan",
        order_by="CommunityComment.created_at.asc()",
    )

    __table_args__ = (
        sa.CheckConstraint(
            "rating IS NULL OR (rating >= 1.0 AND rating <= 5.0)",
            name="ck_community_posts_rating_range",
        ),
        sa.CheckConstraint(
            "text IS NOT NULL OR image_url IS NOT NULL",
            name="ck_community_posts_has_content",
        ),
    )


class CommunityPostLike(Base):
    __tablename__ = "community_post_likes"

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

    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
    )

    post = relationship(
        "CommunityPost",
        back_populates="likes",
    )

    user = relationship(
        "User",
    )

    __table_args__ = (
        sa.UniqueConstraint(
            "post_id",
            "user_id",
            name="uq_community_post_likes_post_user",
        ),
    )


class CommunityPostSave(Base):
    __tablename__ = "community_post_saves"

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

    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
    )

    post = relationship(
        "CommunityPost",
        back_populates="saves",
    )

    user = relationship(
        "User",
    )

    __table_args__ = (
        sa.UniqueConstraint(
            "post_id",
            "user_id",
            name="uq_community_post_saves_post_user",
        ),
    )


class CommunityComment(Base):
    __tablename__ = "community_comments"

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

    user_id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        sa.ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    text: Mapped[str] = mapped_column(
        sa.Text,
        nullable=False,
    )

    is_visible: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=True,
        server_default=sa.true(),
        index=True,
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
        back_populates="comments",
    )

    user = relationship(
        "User",
    )
