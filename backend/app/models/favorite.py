"""UserFavorite model — tracks which places a user has saved/favourited."""

import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class UserFavorite(Base):
    __tablename__ = "user_favorites"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        server_default=sa.text("gen_random_uuid()"),
        nullable=False,
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

    place_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        sa.ForeignKey(
            "places.id",
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

    __table_args__ = (
        sa.UniqueConstraint(
            "user_id",
            "place_id",
            name="uq_user_favorites_user_place",
        ),
        # Note: index on user_id and place_id created above via index=True
        # to avoid redundancy with the UNIQUE constraint covering both cols.
    )

    user = relationship(
        "User",
        foreign_keys=[user_id],
        back_populates="favorites",
    )

    place = relationship(
        "Place",
        foreign_keys=[place_id],
        back_populates="favorites",
    )
