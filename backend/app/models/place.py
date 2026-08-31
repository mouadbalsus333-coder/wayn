import enum
import uuid
from datetime import datetime

import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class VerificationStatus(str, enum.Enum):
    UNVERIFIED = "UNVERIFIED"
    PENDING = "PENDING"
    VERIFIED = "VERIFIED"
    REJECTED = "REJECTED"


class Place(Base):
    __tablename__ = "places"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        nullable=False,
    )

    category_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False),
        sa.ForeignKey(
            "categories.id",
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    owner_user_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False),
        sa.ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    verification_status: Mapped[VerificationStatus] = mapped_column(
        sa.Enum(
            VerificationStatus,
            name="verification_status",
            create_constraint=False,
        ),
        nullable=False,
        server_default="UNVERIFIED",
    )

    name: Mapped[str] = mapped_column(
        sa.String(255),
        nullable=False,
    )

    city: Mapped[str] = mapped_column(
        sa.String(255),
        nullable=False,
    )

    category_name: Mapped[str] = mapped_column(
        "category",
        sa.String(255),
        nullable=False,
    )

    image_url: Mapped[str] = mapped_column(
        sa.String(1024),
        nullable=False,
    )

    rating: Mapped[float] = mapped_column(
        sa.Float,
        nullable=False,
        default=0.0,
    )

    is_open: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=False,
    )

    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=True,
    )

    description: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    address: Mapped[str | None] = mapped_column(
        sa.String(1024),
        nullable=True,
    )

    phone: Mapped[str | None] = mapped_column(
        sa.String(64),
        nullable=True,
    )

    website: Mapped[str | None] = mapped_column(
        sa.String(1024),
        nullable=True,
    )

    latitude: Mapped[float | None] = mapped_column(
        sa.Float,
        nullable=True,
    )

    longitude: Mapped[float | None] = mapped_column(
        sa.Float,
        nullable=True,
    )

    location: Mapped[object | None] = mapped_column(
        Geography(
            geometry_type="POINT",
            srid=4326,
        ),
        nullable=True,
    )

    images: Mapped[list[str]] = mapped_column(
        sa.JSON,
        nullable=False,
        default=list,
    )

    services: Mapped[list[str]] = mapped_column(
        sa.JSON,
        nullable=False,
        default=list,
    )

    opening_time: Mapped[str | None] = mapped_column(
        sa.String(16),
        nullable=True,
    )

    closing_time: Mapped[str | None] = mapped_column(
        sa.String(16),
        nullable=True,
    )

    working_hours_json: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
    )

    deleted_at: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    reviews_count: Mapped[int] = mapped_column(
        sa.Integer,
        nullable=False,
        default=0,
    )

    visits_count: Mapped[int] = mapped_column(
        sa.Integer,
        nullable=False,
        default=0,
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
        sa.Index(
            "ix_places_category_id",
            "category_id",
        ),
        sa.Index(
            "ix_places_location",
            "location",
            postgresql_using="gist",
        ),
        sa.Index(
            "ix_places_owner_user_id",
            "owner_user_id",
        ),
        sa.Index(
            "ix_places_verification_status",
            "verification_status",
        ),
        sa.Index(
            "ix_places_deleted_at",
            "deleted_at",
        ),
    )

    # ============================================================
    # Relationships
    # ============================================================

    category = relationship(
        "Category",
        back_populates="places",
    )

    owner = relationship(
        "User",
        foreign_keys=[owner_user_id],
        back_populates="owned_places",
    )

    reviews = relationship(
        "PlaceReview",
        back_populates="place",
        cascade="all, delete-orphan",
    )

    favorites = relationship(
        "UserFavorite",
        back_populates="place",
        cascade="all, delete-orphan",
    )

    contributions = relationship(
        "PlaceContribution",
        back_populates="place",
        cascade="all, delete-orphan",
        order_by="PlaceContribution.created_at.desc()",
    )

    community_posts = relationship(
        "CommunityPost",
        back_populates="place",
        cascade="all, delete-orphan",
        order_by="CommunityPost.created_at.desc()",
    )