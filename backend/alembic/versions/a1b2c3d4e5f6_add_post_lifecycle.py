"""Add post lifecycle state to community_posts

Adds explicit soft-delete / hide tracking so a user can hide a post or
delete it without losing it (sections "المنشورات المحذوفة" and
"المنشورات المخفية" inside the app settings).

Adds:
- deleted_at: soft delete timestamp
- hidden_at: hide timestamp
- visibility_state: VISIBLE | HIDDEN | DELETED

`is_visible` is intentionally kept (and stays in sync with
`visibility_state`) because the public feed already filters on it.

Revision ID: a1b2c3d4e5f6
Revises: n8o9p0q1r2s3
Create Date: 2026-09-17
"""
from __future__ import annotations

from alembic import op

# revision identifiers
revision = "a1b2c3d4e5f6"
down_revision = "n8o9p0q1r2s3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ============================================================
    # visibility_state enum type
    # ============================================================
    #
    # Created explicitly and defensively so a partially applied or
    # re-run migration never fails on an already existing type.

    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM pg_type
                WHERE typname = 'post_visibility_state'
            ) THEN
                CREATE TYPE post_visibility_state AS ENUM
                    ('VISIBLE', 'HIDDEN', 'DELETED');
            END IF;
        END
        $$;
        """
    )

    # ============================================================
    # Columns
    # ============================================================

    op.execute(
        "ALTER TABLE community_posts "
        "ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ"
    )

    op.execute(
        "ALTER TABLE community_posts "
        "ADD COLUMN IF NOT EXISTS hidden_at TIMESTAMPTZ"
    )

    op.execute(
        "ALTER TABLE community_posts "
        "ADD COLUMN IF NOT EXISTS visibility_state "
        "post_visibility_state NOT NULL DEFAULT 'VISIBLE'"
    )

    # ============================================================
    # Backfill
    # ============================================================
    #
    # Existing posts that were already invisible are considered HIDDEN.
    # Explicit casts are required because visibility_state is a
    # PostgreSQL ENUM, while CASE string literals are otherwise treated
    # as TEXT.

    op.execute(
        """
        UPDATE community_posts
        SET visibility_state = CASE
            WHEN is_visible IS NOT TRUE
                THEN 'HIDDEN'::post_visibility_state
            ELSE 'VISIBLE'::post_visibility_state
        END
        """
    )

    # ============================================================
    # Indexes
    # ============================================================

    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_community_posts_deleted_at "
        "ON community_posts (deleted_at)"
    )

    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_community_posts_hidden_at "
        "ON community_posts (hidden_at)"
    )

    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_community_posts_visibility_state "
        "ON community_posts (visibility_state)"
    )


def downgrade() -> None:
    op.execute(
        "DROP INDEX IF EXISTS ix_community_posts_visibility_state"
    )

    op.execute(
        "DROP INDEX IF EXISTS ix_community_posts_hidden_at"
    )

    op.execute(
        "DROP INDEX IF EXISTS ix_community_posts_deleted_at"
    )

    op.execute(
        "ALTER TABLE community_posts "
        "DROP COLUMN IF EXISTS visibility_state"
    )

    op.execute(
        "ALTER TABLE community_posts "
        "DROP COLUMN IF EXISTS hidden_at"
    )

    op.execute(
        "ALTER TABLE community_posts "
        "DROP COLUMN IF EXISTS deleted_at"
    )

    op.execute(
        "DROP TYPE IF EXISTS post_visibility_state"
    )
