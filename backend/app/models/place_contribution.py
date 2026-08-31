"""Place contribution model."""

import enum
from datetime import datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class PlaceContributionType(str, enum.Enum):
    CREATE_PLACE = "CREATE_PLACE"
    UPDATE_PLACE = "UPDATE_PLACE"
    ADD_IMAGE = "ADD_IMAGE"
    UPDATE_INFORMATION = "UPDATE_INFORMATION"
    VERIFY_PLACE = "VERIFY_PLACE"


class PlaceContributionStatus(str, enum.Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    CANCELLED = "CANCELLED"


class PlaceContribution(Base):
    __tablename__ = "place_contributions"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        sa.ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    place_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        sa.ForeignKey(
            "places.id",
            ondelete="CASCADE",
        ),
        nullable=True,
        index=True,
    )

    type: Mapped[PlaceContributionType] = mapped_column(
        sa.Enum(
            PlaceContributionType,
            name="place_contribution_type",
            native_enum=True,
        ),
        nullable=False,
        index=True,
    )

    status: Mapped[PlaceContributionStatus] = mapped_column(
        sa.Enum(
            PlaceContributionStatus,
            name="place_contribution_status",
            native_enum=True,
        ),
        nullable=False,
        default=PlaceContributionStatus.PENDING,
        server_default=PlaceContributionStatus.PENDING.value,
        index=True,
    )

    title: Mapped[str] = mapped_column(
        sa.String(255),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    payload: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
        server_default=sa.text("'{}'::jsonb"),
    )

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

    rejection_reason: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    points_awarded: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
        default=0,
        server_default="0",
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
        back_populates="place_contributions",
    )

    place = relationship(
        "Place",
        back_populates="contributions",
    )

    reviewer = relationship(
        "AdminUser",
        foreign_keys=[reviewed_by],
    )
