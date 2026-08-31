"""Add community models.

Revision ID: e2b15b5f296d
Revises: 3f754f995de2
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "e2b15b5f296d"
down_revision = "3f754f995de2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ============================================================
    # community_posts
    # ============================================================

    op.create_table(
        "community_posts",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "place_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "text",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "image_url",
            sa.String(length=1024),
            nullable=True,
        ),
        sa.Column(
            "rating",
            sa.Numeric(precision=2, scale=1),
            nullable=True,
        ),
        sa.Column(
            "is_visible",
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
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["place_id"],
            ["places.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint(
            "rating IS NULL OR (rating >= 1.0 AND rating <= 5.0)",
            name="ck_community_posts_rating_range",
        ),
        sa.CheckConstraint(
            "text IS NOT NULL OR image_url IS NOT NULL",
            name="ck_community_posts_has_content",
        ),
    )

    op.create_index(
        "ix_community_posts_user_id",
        "community_posts",
        ["user_id"],
    )

    op.create_index(
        "ix_community_posts_place_id",
        "community_posts",
        ["place_id"],
    )

    op.create_index(
        "ix_community_posts_is_visible",
        "community_posts",
        ["is_visible"],
    )

    op.create_index(
        "ix_community_posts_created_at",
        "community_posts",
        ["created_at"],
    )

    # ============================================================
    # community_post_likes
    # ============================================================

    op.create_table(
        "community_post_likes",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "post_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["post_id"],
            ["community_posts.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "post_id",
            "user_id",
            name="uq_community_post_likes_post_user",
        ),
    )

    op.create_index(
        "ix_community_post_likes_post_id",
        "community_post_likes",
        ["post_id"],
    )

    op.create_index(
        "ix_community_post_likes_user_id",
        "community_post_likes",
        ["user_id"],
    )

    # ============================================================
    # community_post_saves
    # ============================================================

    op.create_table(
        "community_post_saves",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "post_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["post_id"],
            ["community_posts.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "post_id",
            "user_id",
            name="uq_community_post_saves_post_user",
        ),
    )

    op.create_index(
        "ix_community_post_saves_post_id",
        "community_post_saves",
        ["post_id"],
    )

    op.create_index(
        "ix_community_post_saves_user_id",
        "community_post_saves",
        ["user_id"],
    )

    # ============================================================
    # community_comments
    # ============================================================

    op.create_table(
        "community_comments",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "post_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "text",
            sa.Text(),
            nullable=False,
        ),
        sa.Column(
            "is_visible",
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
            ["post_id"],
            ["community_posts.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_community_comments_post_id",
        "community_comments",
        ["post_id"],
    )

    op.create_index(
        "ix_community_comments_user_id",
        "community_comments",
        ["user_id"],
    )

    op.create_index(
        "ix_community_comments_is_visible",
        "community_comments",
        ["is_visible"],
    )

    op.create_index(
        "ix_community_comments_created_at",
        "community_comments",
        ["created_at"],
    )


def downgrade() -> None:
    # Drop in reverse dependency order.
    op.drop_index(
        "ix_community_comments_created_at",
        table_name="community_comments",
    )
    op.drop_index(
        "ix_community_comments_is_visible",
        table_name="community_comments",
    )
    op.drop_index(
        "ix_community_comments_user_id",
        table_name="community_comments",
    )
    op.drop_index(
        "ix_community_comments_post_id",
        table_name="community_comments",
    )
    op.drop_table("community_comments")

    op.drop_index(
        "ix_community_post_saves_user_id",
        table_name="community_post_saves",
    )
    op.drop_index(
        "ix_community_post_saves_post_id",
        table_name="community_post_saves",
    )
    op.drop_table("community_post_saves")

    op.drop_index(
        "ix_community_post_likes_user_id",
        table_name="community_post_likes",
    )
    op.drop_index(
        "ix_community_post_likes_post_id",
        table_name="community_post_likes",
    )
    op.drop_table("community_post_likes")

    op.drop_index(
        "ix_community_posts_created_at",
        table_name="community_posts",
    )
    op.drop_index(
        "ix_community_posts_is_visible",
        table_name="community_posts",
    )
    op.drop_index(
        "ix_community_posts_place_id",
        table_name="community_posts",
    )
    op.drop_index(
        "ix_community_posts_user_id",
        table_name="community_posts",
    )
    op.drop_table("community_posts")
