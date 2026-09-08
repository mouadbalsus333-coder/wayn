"""Add app settings table with the store-ads rotation default.

Revision ID: k6f7g8h9i0j1
Revises: j5e6f7a8b9c0
Create Date: 2026-09-08
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "k6f7g8h9i0j1"
down_revision: Union[str, Sequence[str], None] = "j5e6f7a8b9c0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "app_settings",
        sa.Column("key", sa.String(length=100), primary_key=True),
        sa.Column("value", sa.String(length=255), nullable=False),
        sa.Column("description", sa.String(length=255), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    op.execute(
        """
        INSERT INTO app_settings (key, value, description)
        VALUES (
            'store_ads_rotation_seconds',
            '5',
            'Seconds between store ad banner rotations'
        )
        ON CONFLICT (key) DO NOTHING
        """
    )


def downgrade() -> None:
    op.drop_table("app_settings")
