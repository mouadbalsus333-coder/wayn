"""Add place_socials table for place contact/social links.

Revision ID: l1m2n3o4p5q6
Revises: k6f7g8h9i0j1
Create Date: 2026-09-10
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "l1m2n3o4p5q6"
down_revision: Union[str, Sequence[str], None] = "k6f7g8h9i0j1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

place_social_type_enum = postgresql.ENUM(
    "FACEBOOK",
    "YOUTUBE",
    "WHATSAPP",
    "WEB",
    "TIKTOK",
    "INSTAGRAM",
    name="place_social_type",
    create_type=False,
)


def upgrade() -> None:
    place_social_type_enum.create(
        op.get_bind(),
        checkfirst=True,
    )

    op.create_table(
        "place_socials",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=False),
            primary_key=True,
            nullable=False,
        ),
        sa.Column(
            "place_id",
            postgresql.UUID(as_uuid=False),
            sa.ForeignKey("places.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "social_type",
            place_social_type_enum,
            nullable=False,
        ),
        sa.Column(
            "value",
            sa.String(length=1024),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "place_id",
            "social_type",
            name="uq_place_socials_place_type",
        ),
    )
    op.create_index(
        "ix_place_socials_place_id",
        "place_socials",
        ["place_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_place_socials_place_id", table_name="place_socials")
    op.drop_table("place_socials")

    place_social_type_enum.drop(
        op.get_bind(),
        checkfirst=True,
    )