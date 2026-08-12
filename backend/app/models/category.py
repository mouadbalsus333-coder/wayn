import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class Category(Base):
    __tablename__ = 'categories'

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        nullable=False,
    )
    parent_id: Mapped[str | None] = mapped_column(
        UUID(as_uuid=False),
        sa.ForeignKey(
            "categories.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )
    name_ar: Mapped[str] = mapped_column(sa.String(255), nullable=False)
    name_en: Mapped[str | None] = mapped_column(sa.String(255), nullable=True)
    icon: Mapped[str | None] = mapped_column(sa.String(255), nullable=True)
    sort_order: Mapped[int] = mapped_column(sa.Integer, nullable=False, default=0)
    is_active: Mapped[bool] = mapped_column(sa.Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now(), nullable=False
    )

    places = relationship('Place', back_populates='category')
    parent = relationship('Category', remote_side=[id], back_populates='children')
    children = relationship('Category', back_populates='parent')

