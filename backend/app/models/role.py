from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class Role(Base):
    __tablename__ = "roles"

    id: Mapped[int] = mapped_column(
        sa.Integer,
        primary_key=True,
        autoincrement=True,
    )

    name: Mapped[str] = mapped_column(
        sa.String(100),
        unique=True,
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        sa.String(255),
        nullable=True,
    )

    is_active: Mapped[bool] = mapped_column(
        sa.Boolean,
        nullable=False,
        default=True,
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

    admin_users = relationship(
        "AdminUser",
        secondary="admin_user_roles",
        back_populates="roles",
    )

    permissions = relationship(
        "Permission",
        secondary="role_permissions",
        back_populates="roles",
    )