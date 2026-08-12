from logging.config import fileConfig

import asyncio
import os
import sys

from alembic import context
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import create_async_engine

project_root = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")
)

if project_root not in sys.path:
    sys.path.insert(0, project_root)

from app.core.config import settings
from app.database.base import Base

# Existing application models
from app.models.category import Category  # noqa: F401
from app.models.place import Place  # noqa: F401
from app.models.user import User  # noqa: F401

# Admin system models
from app.models.admin_user import AdminUser  # noqa: F401
from app.models.role import Role  # noqa: F401
from app.models.permission import Permission  # noqa: F401
from app.models import admin_associations  # noqa: F401


config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)


db_url = settings.database_url

config.set_main_option(
    "sqlalchemy.url",
    db_url,
)

target_metadata = Base.metadata


def include_object(
    object,
    name,
    type_,
    reflected,
    compare_to,
):
    """
    Prevent Alembic from managing the PostGIS system table.
    """

    if (
        type_ == "table"
        and reflected
        and name == "spatial_ref_sys"
    ):
        return False

    return True


def run_migrations_offline() -> None:
    """Run migrations in offline mode."""

    url = config.get_main_option("sqlalchemy.url")

    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_object=include_object,
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection) -> None:
    """Run migrations using an active database connection."""

    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        include_object=include_object,
    )

    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    """Run migrations using an active database connection."""

    connectable = create_async_engine(
        db_url,
        poolclass=pool.NullPool,
        future=True,
    )

    try:
        async with connectable.connect() as connection:
            await connection.run_sync(do_run_migrations)
    finally:
        await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())