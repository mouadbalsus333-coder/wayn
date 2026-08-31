"""User model for the WAYN backend."""

from datetime import datetime
from enum import Enum
from uuid import UUID

import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class AccountStatus(str, Enum):
    ACTIVE = "ACTIVE"
    HIDDEN = "HIDDEN"
    SUSPENDED = "SUSPENDED"
    BANNED = "BANNED"


class User(Base):
    __tablename__ = "users"

    # ============================================================
    # Identity
    # ============================================================

    id: Mapped[UUID] = mapped_column(
        sa.Uuid,
        primary_key=True,
        default=sa.text("gen_random_uuid()"),
        server_default=sa.text("gen_random_uuid()"),
    )

    email: Mapped[str] = mapped_column(
        sa.String(320),
        unique=True,
        nullable=False,
        index=True,
    )

    password_hash: Mapped[str | None] = mapped_column(
        sa.String(255),
        nullable=True,
    )

    google_id: Mapped[str | None] = mapped_column(
        sa.String(255),
        unique=True,
        nullable=True,
        index=True,
    )

    full_name: Mapped[str] = mapped_column(
        sa.String(255),
        nullable=False,
    )

    username: Mapped[str] = mapped_column(
        sa.String(50),
        unique=True,
        nullable=False,
        index=True,
    )

    phone: Mapped[str | None] = mapped_column(
        sa.String(32),
        unique=True,
        nullable=True,
        index=True,
    )

    # ============================================================
    # Profile
    # ============================================================

    avatar_id: Mapped[str | None] = mapped_column(
        sa.String(100),
        nullable=True,
    )

    bio: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    # ============================================================
    # Location
    # ============================================================

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

    location_source: Mapped[str | None] = mapped_column(
        sa.String(20),
        nullable=True,
    )

    # ============================================================
    # User Points
    # ============================================================
    #
    # Points belong directly to the user.
    #
    # They are intentionally NOT stored inside UserWallet.
    #
    # Every balance mutation must also create an immutable
    # UserPointTransaction ledger record.
    #

    points: Mapped[int] = mapped_column(
        sa.BigInteger,
        nullable=False,
        default=0,
        server_default="0",
    )

    # ============================================================
    # Account Status
    # ============================================================

    account_status: Mapped[AccountStatus] = mapped_column(
        sa.Enum(
            AccountStatus,
            name="account_status",
            native_enum=True,
        ),
        nullable=False,
        default=AccountStatus.ACTIVE,
        server_default=AccountStatus.ACTIVE.value,
        index=True,
    )

    status_reason: Mapped[str | None] = mapped_column(
        sa.Text,
        nullable=True,
    )

    status_changed_at: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    status_changed_by: Mapped[int | None] = mapped_column(
        sa.Integer,
        nullable=True,
    )

    suspended_until: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
    )

    # ============================================================
    # Authentication Invalidation
    # ============================================================

    token_version: Mapped[int] = mapped_column(
        sa.Integer,
        nullable=False,
        default=1,
        server_default="1",
    )

    # ============================================================
    # Account Flags
    # ============================================================

    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=True,
        server_default=sa.text("true"),
    )

    is_verified: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=False,
        server_default=sa.text("false"),
    )

    # ============================================================
    # Login / Timestamps
    # ============================================================

    last_login_at: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True),
        nullable=True,
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

    # ============================================================
    # Relationships
    # ============================================================

    owned_places = relationship(
        "Place",
        foreign_keys="Place.owner_user_id",
        back_populates="owner",
    )

    reviews = relationship(
        "PlaceReview",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    favorites = relationship(
        "UserFavorite",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    place_contributions = relationship(
        "PlaceContribution",
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="PlaceContribution.created_at.desc()",
    )

    community_posts = relationship(
        "CommunityPost",
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="CommunityPost.created_at.desc()",
    )

    # ============================================================
    # Points Transactions
    # ============================================================
    #
    # Independent ledger for User.points.
    #
    # This records:
    # - points earned
    # - points removed
    # - admin adjustments
    # - penalties
    # - rewards
    # - other point operations
    #

    point_transactions = relationship(
        "UserPointTransaction",
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="UserPointTransaction.created_at.desc()",
    )

    # ============================================================
    # Wallet
    # ============================================================
    #
    # UserWallet contains coins and wallet-specific operations.
    # Points are intentionally kept outside the wallet.
    #

    wallet = relationship(
        "UserWallet",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )