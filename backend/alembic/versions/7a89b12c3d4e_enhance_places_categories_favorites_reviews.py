"""Enhance places, categories, add user_favorites and place_reviews tables.

Revision ID: 7a89b12c3d4e
Revises: 0ff6ed140b0b
Create Date: 2026-08-10 08:25:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "7a89b12c3d4e"
down_revision = "0ff6ed140b0b"
branch_labels = None
depends_on = None

verification_status_enum = postgresql.ENUM(
    "UNVERIFIED",
    "PENDING",
    "VERIFIED",
    "REJECTED",
    name="verification_status",
    create_type=False,
)


def upgrade() -> None:
    # 1. Create ENUM type for verification_status
    verification_status_enum.create(
        op.get_bind(),
        checkfirst=True,
    )

    # 2. Add columns to categories
    op.add_column(
        "categories",
        sa.Column(
            "parent_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("categories.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_categories_parent_id",
        "categories",
        ["parent_id"],
    )

    # 3. Add columns to places
    op.add_column(
        "places",
        sa.Column(
            "owner_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.add_column(
        "places",
        sa.Column(
            "verification_status",
            verification_status_enum,
            nullable=False,
            server_default="UNVERIFIED",
        ),
    )
    op.add_column(
        "places",
        sa.Column(
            "working_hours_json",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )
    op.add_column(
        "places",
        sa.Column(
            "deleted_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_places_owner_user_id",
        "places",
        ["owner_user_id"],
    )
    op.create_index(
        "ix_places_verification_status",
        "places",
        ["verification_status"],
    )
    op.create_index(
        "ix_places_deleted_at",
        "places",
        ["deleted_at"],
    )

    # 4. Create user_favorites table
    op.create_table(
        "user_favorites",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            nullable=False,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "place_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("places.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "user_id",
            "place_id",
            name="uq_user_favorites_user_place",
        ),
    )
    op.create_index(
        "ix_user_favorites_user_id",
        "user_favorites",
        ["user_id"],
    )
    op.create_index(
        "ix_user_favorites_place_id",
        "user_favorites",
        ["place_id"],
    )

    # 5. Create place_reviews table
    op.create_table(
        "place_reviews",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            nullable=False,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "place_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("places.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "rating",
            sa.Numeric(precision=2, scale=1),
            nullable=False,
        ),
        sa.Column(
            "comment",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "images",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column(
            "is_visible",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "rating >= 1.0 AND rating <= 5.0",
            name="ck_place_reviews_rating_range",
        ),
        sa.UniqueConstraint(
            "user_id",
            "place_id",
            name="uq_place_reviews_user_place",
        ),
    )
    op.create_index(
        "ix_place_reviews_place_id",
        "place_reviews",
        ["place_id"],
    )
    op.create_index(
        "ix_place_reviews_user_id",
        "place_reviews",
        ["user_id"],
    )


def downgrade() -> None:
    # 1. Drop place_reviews table
    op.drop_index("ix_place_reviews_user_id", table_name="place_reviews")
    op.drop_index("ix_place_reviews_place_id", table_name="place_reviews")
    op.drop_table("place_reviews")

    # 2. Drop user_favorites table
    op.drop_index("ix_user_favorites_place_id", table_name="user_favorites")
    op.drop_index("ix_user_favorites_user_id", table_name="user_favorites")
    op.drop_table("user_favorites")

    # 3. Drop columns from places
    op.drop_index("ix_places_deleted_at", table_name="places")
    op.drop_index("ix_places_verification_status", table_name="places")
    op.drop_index("ix_places_owner_user_id", table_name="places")
    op.drop_column("places", "deleted_at")
    op.drop_column("places", "working_hours_json")
    op.drop_column("places", "verification_status")
    op.drop_column("places", "owner_user_id")

    # 4. Drop column from categories
    op.drop_index("ix_categories_parent_id", table_name="categories")
    op.drop_column("categories", "parent_id")

    # 5. Drop ENUM type
    verification_status_enum.drop(
        op.get_bind(),
        checkfirst=True,
    )
