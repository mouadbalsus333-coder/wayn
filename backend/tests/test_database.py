"""Database schema and infrastructure tests."""

import pytest
import asyncpg

from app.core.config import settings


def _sync_url() -> str:
    return settings.database_url.replace(
        "postgresql+asyncpg://",
        "postgresql://",
        1,
    )


@pytest.fixture
async def conn():
    connection = await asyncpg.connect(_sync_url())
    try:
        yield connection
    finally:
        await connection.close()


LATEST_ALEMBIC_HEAD = "7e4534ba168d"


REQUIRED_TABLES = [
    "categories",
    "places",
    "users",
    "admin_users",
    "roles",
    "permissions",
    "admin_user_roles",
    "role_permissions",
    "user_favorites",
    "place_reviews",
    "alembic_version",
]


USER_COLUMNS = [
    "id",
    "email",
    "password_hash",
    "full_name",
    "username",
    "phone",
    "google_id",
    "avatar_id",
    "bio",
    "latitude",
    "longitude",
    "location",
    "location_source",
    "account_status",
    "status_reason",
    "status_changed_at",
    "status_changed_by",
    "suspended_until",
    "token_version",
    "is_active",
    "is_verified",
    "last_login_at",
    "created_at",
    "updated_at",
]


PLACE_COLUMNS = [
    "id",
    "category_id",
    "name",
    "city",
    "category",
    "image_url",
    "rating",
    "is_open",
    "is_active",
    "description",
    "address",
    "phone",
    "website",
    "latitude",
    "longitude",
    "location",
    "images",
    "services",
    "opening_time",
    "closing_time",
    "reviews_count",
    "visits_count",
    "created_at",
    "updated_at",
    "owner_user_id",
    "verification_status",
    "working_hours_json",
    "deleted_at",
]


CATEGORY_COLUMNS = [
    "id",
    "parent_id",
    "name_ar",
    "name_en",
    "icon",
    "sort_order",
    "is_active",
    "created_at",
    "updated_at",
]


FAVORITE_COLUMNS = [
    "id",
    "user_id",
    "place_id",
    "created_at",
]


REVIEW_COLUMNS = [
    "id",
    "place_id",
    "user_id",
    "rating",
    "comment",
    "images",
    "is_visible",
    "created_at",
    "updated_at",
]


# ------------------------------------------------------------------
# Connection
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_database_connection():
    connection = await asyncpg.connect(_sync_url())
    try:
        assert await connection.fetchval("SELECT 1") == 1
    finally:
        await connection.close()


@pytest.mark.anyio
async def test_database_name(conn):
    assert await conn.fetchval(
        "SELECT current_database()"
    ) == "wayn_test_db"


@pytest.mark.anyio
async def test_schema_is_public(conn):
    assert await conn.fetchval(
        "SELECT current_schema()"
    ) == "public"


# ------------------------------------------------------------------
# Tables
# ------------------------------------------------------------------


@pytest.mark.anyio
@pytest.mark.parametrize("table_name", REQUIRED_TABLES)
async def test_table_exists(conn, table_name):
    exists = await conn.fetchval(
        """
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = $1
        )
        """,
        table_name,
    )

    assert exists is True, (
        f"Table '{table_name}' does not exist"
    )


# ------------------------------------------------------------------
# Alembic
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_alembic_version_is_latest_head(conn):
    version = await conn.fetchval(
        "SELECT version_num FROM alembic_version"
    )

    assert version == LATEST_ALEMBIC_HEAD, (
        f"Database migration is {version}, "
        f"expected {LATEST_ALEMBIC_HEAD}"
    )


# ------------------------------------------------------------------
# PostGIS
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_postgis_extension_exists(conn):
    version = await conn.fetchval(
        """
        SELECT extversion
        FROM pg_extension
        WHERE extname = 'postgis'
        """
    )

    assert version is not None
    assert version.startswith("3.")


@pytest.mark.anyio
async def test_postgis_geometry_columns_view(conn):
    count = await conn.fetchval(
        "SELECT COUNT(*) FROM geometry_columns"
    )

    assert count >= 0


@pytest.mark.anyio
async def test_geography_columns_registered(conn):
    count = await conn.fetchval(
        """
        SELECT COUNT(*)
        FROM geography_columns
        WHERE f_table_name IN ('places', 'users')
        """
    )

    assert count >= 1


# ------------------------------------------------------------------
# account_status enum
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_account_status_enum_exists(conn):
    name = await conn.fetchval(
        """
        SELECT typname
        FROM pg_type
        WHERE typname = 'account_status'
        """
    )

    assert name == "account_status"


@pytest.mark.anyio
async def test_account_status_enum_values(conn):
    rows = await conn.fetch(
        """
        SELECT enumlabel
        FROM pg_enum
        WHERE enumtypid = (
            SELECT oid
            FROM pg_type
            WHERE typname = 'account_status'
        )
        ORDER BY enumsortorder
        """
    )

    values = {row["enumlabel"] for row in rows}

    assert {
        "ACTIVE",
        "HIDDEN",
        "SUSPENDED",
        "BANNED",
    } <= values


# ------------------------------------------------------------------
# Generic column helper
# ------------------------------------------------------------------


async def _assert_columns_exist(
    conn,
    table_name,
    columns,
):
    for column_name in columns:
        exists = await conn.fetchval(
            """
            SELECT EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = $1
                  AND column_name = $2
            )
            """,
            table_name,
            column_name,
        )

        assert exists, (
            f"Column '{column_name}' "
            f"missing from '{table_name}'"
        )


# ------------------------------------------------------------------
# Users
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_users_columns(conn):
    await _assert_columns_exist(
        conn,
        "users",
        USER_COLUMNS,
    )


@pytest.mark.anyio
async def test_users_token_version_default(conn):
    default = await conn.fetchval(
        """
        SELECT column_default
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name = 'token_version'
        """
    )

    assert "1" in str(default)


@pytest.mark.anyio
async def test_users_account_status_default(conn):
    default = await conn.fetchval(
        """
        SELECT column_default
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name = 'account_status'
        """
    )

    assert "ACTIVE" in str(default)


@pytest.mark.anyio
async def test_users_password_hash_nullable(conn):
    nullable = await conn.fetchval(
        """
        SELECT is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name = 'password_hash'
        """
    )

    assert nullable == "YES"


# ------------------------------------------------------------------
# Places
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_places_columns(conn):
    await _assert_columns_exist(
        conn,
        "places",
        PLACE_COLUMNS,
    )


@pytest.mark.anyio
async def test_places_category_column_is_string(conn):
    column_type = await conn.fetchval(
        """
        SELECT data_type
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'places'
          AND column_name = 'category'
        """
    )

    assert (
        "character" in column_type
        or "text" in column_type
    )


@pytest.mark.anyio
async def test_places_verification_status_column(conn):
    column_type = await conn.fetchval(
        """
        SELECT udt_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'places'
          AND column_name = 'verification_status'
        """
    )

    assert column_type == "verification_status"


# ------------------------------------------------------------------
# Categories
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_categories_columns(conn):
    await _assert_columns_exist(
        conn,
        "categories",
        CATEGORY_COLUMNS,
    )


@pytest.mark.anyio
async def test_categories_parent_id_is_nullable(conn):
    nullable = await conn.fetchval(
        """
        SELECT is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'categories'
          AND column_name = 'parent_id'
        """
    )

    assert nullable == "YES"


# ------------------------------------------------------------------
# Favorites
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_user_favorites_columns(conn):
    await _assert_columns_exist(
        conn,
        "user_favorites",
        FAVORITE_COLUMNS,
    )


# ------------------------------------------------------------------
# Reviews
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_place_reviews_columns(conn):
    await _assert_columns_exist(
        conn,
        "place_reviews",
        REVIEW_COLUMNS,
    )


# ------------------------------------------------------------------
# Constraints
# ------------------------------------------------------------------


async def _constraint_exists(
    conn,
    table_name,
    constraint_name,
):
    return await conn.fetchval(
        """
        SELECT EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conrelid = $1::regclass
              AND conname = $2
        )
        """,
        table_name,
        constraint_name,
    )


@pytest.mark.anyio
async def test_user_favorites_unique_constraint(conn):
    assert await _constraint_exists(
        conn,
        "user_favorites",
        "uq_user_favorites_user_place",
    )


@pytest.mark.anyio
async def test_place_reviews_unique_constraint(conn):
    assert await _constraint_exists(
        conn,
        "place_reviews",
        "uq_place_reviews_user_place",
    )


@pytest.mark.anyio
async def test_place_reviews_rating_constraint(conn):
    assert await _constraint_exists(
        conn,
        "place_reviews",
        "ck_place_reviews_rating_range",
    )


# ------------------------------------------------------------------
# Admin system
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_admin_users_columns(conn):
    rows = await conn.fetch(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'admin_users'
        """
    )

    names = {row["column_name"] for row in rows}

    assert {
        "id",
        "email",
        "password_hash",
        "full_name",
        "is_active",
        "last_login_at",
        "created_at",
        "updated_at",
    } <= names


@pytest.mark.anyio
async def test_roles_columns(conn):
    rows = await conn.fetch(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'roles'
        """
    )

    names = {row["column_name"] for row in rows}

    assert {
        "id",
        "name",
        "description",
        "is_active",
        "created_at",
        "updated_at",
    } <= names


@pytest.mark.anyio
async def test_permissions_columns(conn):
    rows = await conn.fetch(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'permissions'
        """
    )

    names = {row["column_name"] for row in rows}

    assert {
        "id",
        "name",
        "description",
        "created_at",
    } <= names


# ------------------------------------------------------------------
# Indexes
# ------------------------------------------------------------------


async def _index_names(conn, table_name):
    rows = await conn.fetch(
        """
        SELECT indexname
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = $1
        """,
        table_name,
    )

    return [
        row["indexname"].lower()
        for row in rows
    ]


@pytest.mark.anyio
async def test_users_indexes(conn):
    names = await _index_names(
        conn,
        "users",
    )

    assert any(
        "email" in name
        for name in names
    )

    assert any(
        "username" in name
        for name in names
    )


@pytest.mark.anyio
async def test_places_indexes(conn):
    names = await _index_names(
        conn,
        "places",
    )

    for required in (
        "category_id",
        "location",
        "owner_user_id",
        "verification_status",
        "deleted_at",
    ):
        assert any(
            required in name
            for name in names
        ), (
            f"Missing places index containing "
            f"'{required}'"
        )


@pytest.mark.anyio
async def test_categories_indexes(conn):
    names = await _index_names(
        conn,
        "categories",
    )

    assert any(
        "parent_id" in name
        for name in names
    )


@pytest.mark.anyio
async def test_user_favorites_indexes(conn):
    names = await _index_names(
        conn,
        "user_favorites",
    )

    assert any(
        "user_id" in name
        for name in names
    )

    assert any(
        "place_id" in name
        for name in names
    )


@pytest.mark.anyio
async def test_place_reviews_indexes(conn):
    names = await _index_names(
        conn,
        "place_reviews",
    )

    assert any(
        "user_id" in name
        for name in names
    )

    assert any(
        "place_id" in name
        for name in names
    )


# ------------------------------------------------------------------
# Foreign Keys
# ------------------------------------------------------------------


async def _foreign_key_references(
    conn,
    table_name,
):
    rows = await conn.fetch(
        """
        SELECT confrelid::regclass AS referenced_table
        FROM pg_constraint
        WHERE conrelid = $1::regclass
          AND contype = 'f'
        """,
        table_name,
    )

    return [
        str(row["referenced_table"])
        for row in rows
    ]


@pytest.mark.anyio
async def test_places_category_id_fk(conn):
    refs = await _foreign_key_references(
        conn,
        "places",
    )

    assert any(
        "categories" in ref
        for ref in refs
    )


@pytest.mark.anyio
async def test_places_owner_user_id_fk(conn):
    refs = await _foreign_key_references(
        conn,
        "places",
    )

    assert any(
        "users" in ref
        for ref in refs
    )


@pytest.mark.anyio
async def test_categories_parent_id_self_fk(conn):
    refs = await _foreign_key_references(
        conn,
        "categories",
    )

    assert any(
        "categories" in ref
        for ref in refs
    )


@pytest.mark.anyio
async def test_user_favorites_fks(conn):
    refs = await _foreign_key_references(
        conn,
        "user_favorites",
    )

    assert any(
        "users" in ref
        for ref in refs
    )

    assert any(
        "places" in ref
        for ref in refs
    )


@pytest.mark.anyio
async def test_place_reviews_fks(conn):
    refs = await _foreign_key_references(
        conn,
        "place_reviews",
    )

    assert any(
        "users" in ref
        for ref in refs
    )

    assert any(
        "places" in ref
        for ref in refs
    )


@pytest.mark.anyio
async def test_user_roles_fks(conn):
    refs = await _foreign_key_references(
        conn,
        "admin_user_roles",
    )

    assert any(
        "admin_users" in ref
        for ref in refs
    )

    assert any(
        "roles" in ref
        for ref in refs
    )


@pytest.mark.anyio
async def test_role_permissions_fks(conn):
    refs = await _foreign_key_references(
        conn,
        "role_permissions",
    )

    assert any(
        "roles" in ref
        for ref in refs
    )

    assert any(
        "permissions" in ref
        for ref in refs
    )


# ------------------------------------------------------------------
# Existing data
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_existing_category_restaurants(conn):
    row = await conn.fetchrow(
        """
        SELECT name_ar, name_en, is_active, sort_order
        FROM categories
        WHERE name_ar = 'مطاعم'
        """
    )

    assert row is not None
    assert row["is_active"] is True
    assert row["name_en"] == "Restaurants"
    assert row["sort_order"] == 1


@pytest.mark.anyio
async def test_categories_count_expected(conn):
    count = await conn.fetchval(
        "SELECT COUNT(*) FROM categories"
    )

    assert count >= 2


@pytest.mark.anyio
async def test_places_count_zero(conn):
    assert await conn.fetchval(
        "SELECT COUNT(*) FROM places"
    ) == 0


@pytest.mark.anyio
async def test_users_table_has_rows(conn):
    assert await conn.fetchval(
        "SELECT COUNT(*) FROM users"
    ) >= 1


@pytest.mark.anyio
async def test_admin_users_exist(conn):
    assert await conn.fetchval(
        "SELECT COUNT(*) FROM admin_users"
    ) >= 1


@pytest.mark.anyio
async def test_roles_exist(conn):
    assert await conn.fetchval(
        "SELECT COUNT(*) FROM roles "
        "WHERE is_active = true"
    ) >= 1


@pytest.mark.anyio
async def test_permissions_exist(conn):
    assert await conn.fetchval(
        "SELECT COUNT(*) FROM permissions"
    ) >= 1


# ------------------------------------------------------------------
# Super Admin permissions
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_super_admin_has_required_permissions(conn):
    rows = await conn.fetch(
        """
        SELECT p.name
        FROM permissions p
        JOIN role_permissions rp
            ON rp.permission_id = p.id
        JOIN roles r
            ON r.id = rp.role_id
        WHERE r.name = 'super_admin'
        """
    )

    names = {row["name"] for row in rows}

    required = {
        "places.write",
        "places.delete",
        "categories.write",
        "users.read",
    }

    missing = required - names

    assert required <= names, (
        f"super_admin is missing: {sorted(missing)}"
    )