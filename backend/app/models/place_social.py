"""Place social / contact links model.

A Place can have at most one link per social type. WhatsApp stores only the
phone number (the app builds the chat link), while the other types store a
full http(s) URL. Uniqueness is enforced at the DB level with a
(place_id, social_type) unique constraint, and validated in the service layer
so duplicate additions return a clear conflict error.
"""

import enum
import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class PlaceSocialType(str, enum.Enum):
    FACEBOOK = "FACEBOOK"
    YOUTUBE = "YOUTUBE"
    WHATSAPP = "WHATSAPP"
    WEB = "WEB"
    TIKTOK = "TIKTOK"
    INSTAGRAM = "INSTAGRAM"


class PlaceSocial(Base):
    __tablename__ = "place_socials"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
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

    social_type: Mapped[PlaceSocialType] = mapped_column(
        sa.Enum(
            PlaceSocialType,
            name="place_social_type",
            create_constraint=False,
        ),
        nullable=False,
    )

    # For WHATSAPP this holds the phone number only; for the other types it
    # holds the full http(s) URL.
    value: Mapped[str] = mapped_column(
        sa.String(1024),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
    )

    place = relationship(
        "Place",
        back_populates="socials",
    )

    __table_args__ = (
        sa.UniqueConstraint(
            "place_id",
            "social_type",
            name="uq_place_socials_place_type",
        ),
    )