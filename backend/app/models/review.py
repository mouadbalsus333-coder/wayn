"""PlaceReview model — user reviews and ratings for places.

place_reviews is the SOURCE OF TRUTH for ratings.
The service layer keeps places.rating and places.reviews_count
in sync as denormalized fast-read fields.
"""

import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class PlaceReview(Base):
    __tablename__ = "place_reviews"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        server_default=sa.text("gen_random_uuid()"),
        nullable=False,
    )

    place_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        sa.ForeignKey(
            "places.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    user_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        sa.ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    # NUMERIC(2,1) gives one decimal place (e.g. 4.5), avoids float imprecision.
    rating: Mapped[float] = mapped_column(
        sa.Numeric(precision=2, scale=1),
        nullable=False,
    )

    comment: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    # JSONB for efficient querying / GIN indexing if needed later.
    images: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default=sa.text("'[]'::jsonb"),
        default=list,
    )

    is_visible: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        server_default=sa.text("true"),
        default=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        onupdate=sa.func.now(),
        nullable=False,
    )

    __table_args__ = (
        # Enforce rating between 1.0 and 5.0 at DB level.
        sa.CheckConstraint(
            "rating >= 1.0 AND rating <= 5.0",
            name="ck_place_reviews_rating_range",
        ),
        # One review per user per place (can be updated, not duplicated).
        sa.UniqueConstraint(
            "user_id",
            "place_id",
            name="uq_place_reviews_user_place",
        ),
    )

    place = relationship(
        "Place",
        back_populates="reviews",
    )

    user = relationship(
        "User",
        back_populates="reviews",
    )
