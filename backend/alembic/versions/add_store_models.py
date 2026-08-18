"""Add store categories, items, and banners.

Revision ID: 9c4e7a1b2d8f
Revises: 7f1a9c2e4b6d
Create Date: 2026-08-14
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "9c4e7a1b2d8f"
down_revision: Union[str, Sequence[str], None] = "7f1a9c2e4b6d"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ============================================================
    # Store item enums
    #
    # Create them explicitly so PostgreSQL never receives a
    # duplicate CREATE TYPE statement.
    # ============================================================

    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM pg_type
                WHERE typname = 'store_item_type'
            ) THEN
                CREATE TYPE store_item_type AS ENUM (
                    'AVATAR',
                    'FRAME',
                    'GIFT',
                    'SUBSCRIPTION',
                    'PROFILE_BACKGROUND',
                    'BADGE',
                    'OTHER'
                );
            END IF;
        END
        $$;
        """
    )

    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM pg_type
                WHERE typname = 'store_item_currency'
            ) THEN
                CREATE TYPE store_item_currency AS ENUM (
                    'POINTS',
                    'COINS'
                );
            END IF;
        END
        $$;
        """
    )

    # Use PostgreSQL ENUM types without asking SQLAlchemy/Alembic
    # to create them again.
    store_item_type = sa.dialects.postgresql.ENUM(
        "AVATAR",
        "FRAME",
        "GIFT",
        "SUBSCRIPTION",
        "PROFILE_BACKGROUND",
        "BADGE",
        "OTHER",
        name="store_item_type",
        create_type=False,
    )

    store_item_currency = sa.dialects.postgresql.ENUM(
        "POINTS",
        "COINS",
        name="store_item_currency",
        create_type=False,
    )

    # ============================================================
    # Store categories
    # ============================================================

    op.create_table(
        "store_categories",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "name_ar",
            sa.String(length=100),
            nullable=False,
        ),
        sa.Column(
            "name_en",
            sa.String(length=100),
            nullable=False,
        ),
        sa.Column(
            "description_ar",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "description_en",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "icon_url",
            sa.String(length=500),
            nullable=True,
        ),
        sa.Column(
            "image_url",
            sa.String(length=500),
            nullable=True,
        ),
        sa.Column(
            "sort_order",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.true(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_store_categories_sort_order",
        "store_categories",
        ["sort_order"],
        unique=False,
    )

    op.create_index(
        "ix_store_categories_is_active",
        "store_categories",
        ["is_active"],
        unique=False,
    )

    op.create_index(
        "ix_store_categories_created_at",
        "store_categories",
        ["created_at"],
        unique=False,
    )

    # ============================================================
    # Store items
    # ============================================================

    op.create_table(
        "store_items",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "category_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "name_ar",
            sa.String(length=150),
            nullable=False,
        ),
        sa.Column(
            "name_en",
            sa.String(length=150),
            nullable=False,
        ),
        sa.Column(
            "description_ar",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "description_en",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "item_type",
            store_item_type,
            nullable=False,
        ),
        sa.Column(
            "currency",
            store_item_currency,
            nullable=False,
        ),
        sa.Column(
            "price",
            sa.BigInteger(),
            nullable=False,
        ),
        sa.Column(
            "image_url",
            sa.String(length=500),
            nullable=True,
        ),
        sa.Column(
            "asset_id",
            sa.String(length=150),
            nullable=True,
        ),
        sa.Column(
            "duration_days",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "stock",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "sort_order",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.true(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["category_id"],
            ["store_categories.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_store_items_category_id",
        "store_items",
        ["category_id"],
        unique=False,
    )

    op.create_index(
        "ix_store_items_item_type",
        "store_items",
        ["item_type"],
        unique=False,
    )

    op.create_index(
        "ix_store_items_currency",
        "store_items",
        ["currency"],
        unique=False,
    )

    op.create_index(
        "ix_store_items_sort_order",
        "store_items",
        ["sort_order"],
        unique=False,
    )

    op.create_index(
        "ix_store_items_is_active",
        "store_items",
        ["is_active"],
        unique=False,
    )

    op.create_index(
        "ix_store_items_created_at",
        "store_items",
        ["created_at"],
        unique=False,
    )

    # ============================================================
    # Store banners
    # ============================================================

    op.create_table(
        "store_banners",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "title_ar",
            sa.String(length=200),
            nullable=True,
        ),
        sa.Column(
            "title_en",
            sa.String(length=200),
            nullable=True,
        ),
        sa.Column(
            "image_url",
            sa.String(length=500),
            nullable=False,
        ),
        sa.Column(
            "target_url",
            sa.String(length=500),
            nullable=True,
        ),
        sa.Column(
            "sort_order",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.true(),
            nullable=False,
        ),
        sa.Column(
            "starts_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "ends_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_store_banners_sort_order",
        "store_banners",
        ["sort_order"],
        unique=False,
    )

    op.create_index(
        "ix_store_banners_is_active",
        "store_banners",
        ["is_active"],
        unique=False,
    )

    op.create_index(
        "ix_store_banners_starts_at",
        "store_banners",
        ["starts_at"],
        unique=False,
    )

    op.create_index(
        "ix_store_banners_ends_at",
        "store_banners",
        ["ends_at"],
        unique=False,
    )

    op.create_index(
        "ix_store_banners_created_at",
        "store_banners",
        ["created_at"],
        unique=False,
    )


def downgrade() -> None:
    # ============================================================
    # Banners
    # ============================================================

    op.drop_index(
        "ix_store_banners_created_at",
        table_name="store_banners",
    )

    op.drop_index(
        "ix_store_banners_ends_at",
        table_name="store_banners",
    )

    op.drop_index(
        "ix_store_banners_starts_at",
        table_name="store_banners",
    )

    op.drop_index(
        "ix_store_banners_is_active",
        table_name="store_banners",
    )

    op.drop_index(
        "ix_store_banners_sort_order",
        table_name="store_banners",
    )

    op.drop_table("store_banners")

    # ============================================================
    # Items
    # ============================================================

    op.drop_index(
        "ix_store_items_created_at",
        table_name="store_items",
    )

    op.drop_index(
        "ix_store_items_is_active",
        table_name="store_items",
    )

    op.drop_index(
        "ix_store_items_sort_order",
        table_name="store_items",
    )

    op.drop_index(
        "ix_store_items_currency",
        table_name="store_items",
    )

    op.drop_index(
        "ix_store_items_item_type",
        table_name="store_items",
    )

    op.drop_index(
        "ix_store_items_category_id",
        table_name="store_items",
    )

    op.drop_table("store_items")

    # ============================================================
    # Categories
    # ============================================================

    op.drop_index(
        "ix_store_categories_created_at",
        table_name="store_categories",
    )

    op.drop_index(
        "ix_store_categories_is_active",
        table_name="store_categories",
    )

    op.drop_index(
        "ix_store_categories_sort_order",
        table_name="store_categories",
    )

    op.drop_table("store_categories")

    # ============================================================
    # Enums
    # ============================================================

    op.execute(
        """
        DROP TYPE IF EXISTS store_item_currency
        """
    )

    op.execute(
        """
        DROP TYPE IF EXISTS store_item_type
        """
    )