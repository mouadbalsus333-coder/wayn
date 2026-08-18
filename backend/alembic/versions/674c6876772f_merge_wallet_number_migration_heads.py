"""Merge wallet migration branches.

Revision ID: 674c6876772f
Revises: 8b1c2d3e4f5a
Create Date: 2026-08-12 16:36:48.880357
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "674c6876772f"
down_revision = "8b1c2d3e4f5a"
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass