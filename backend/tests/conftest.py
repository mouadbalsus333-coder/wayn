"""Shared test fixtures for WAYN backend QA tests."""
import os
import uuid

import pytest
from dotenv import load_dotenv
from httpx import AsyncClient
from sqlalchemy import select, text, insert
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool

# Load test environment variables BEFORE importing app modules.
dotenv_path = os.path.join(os.path.dirname(__file__), "..", ".env.test")
load_dotenv(dotenv_path=dotenv_path, override=True)
os.environ.setdefault("ENV", "test")

import app.core.database as database_module
from app.core.config import settings
from app.core.database import AsyncSessionLocal, get_session
from app.core.security import hash_password, verify_password
from app.main import app
from app.models.admin_associations import admin_user_roles, role_permissions
from app.models.admin_user import AdminUser
from app.models.category import Category
from app.models.place import Place
from app.models.role import Role
from app.models.user import User
from app.models.permission import Permission

os.environ.setdefault("PYTEST_ANYIO_BACKEND", "asyncio")

# ------------------------------------------------------------------
# Test database engine with NullPool
# ------------------------------------------------------------------
# The global engine uses a connection pool shared across all tests.
# When many async tests run concurrently, the pool can hand out the
# same connection to two operations, causing:
#   asyncpg.InterfaceError: cannot perform operation: another operation is in progress
# Using NullPool creates a fresh connection per session, avoiding this.
_test_engine = create_async_engine(
    settings.database_url,
    echo=False,
    future=True,
    poolclass=NullPool,
)

TestAsyncSessionLocal = sessionmaker(
    bind=_test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

# Patch the global session factory so all fixtures and the app's
# get_session dependency use the test engine with NullPool.
database_module.AsyncSessionLocal = TestAsyncSessionLocal
AsyncSessionLocal = TestAsyncSessionLocal


def unique_suffix():
    return uuid.uuid4().hex[:10]


@pytest.fixture
def anyio_backend():
    return "asyncio"


# ------------------------------------------------------------------
# Fixtures
# ------------------------------------------------------------------


@pytest.fixture
async def client():
    """FastAPI test client (real app, real DB)."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac


@pytest.fixture
async def admin_token():
    """Create a test super-admin, log in, yield token, clean up after."""
    suffix = unique_suffix()
    email = f"qa_admin_{suffix}@wayntest.com"
    password = "AdminPass123!"
    admin_id = None

    async with AsyncSessionLocal() as session:
        admin = AdminUser(
            email=email,
            password_hash=hash_password(password),
            full_name="QA Test Admin",
            is_active=True,
        )
        session.add(admin)
        await session.commit()
        await session.refresh(admin)
        admin_id = admin.id

        result = await session.execute(
            select(Role).where(Role.name == "super_admin")
        )
        super_admin_role = result.scalar_one()

        await session.execute(
            insert(admin_user_roles).values(
                admin_user_id=admin_id,
                role_id=super_admin_role.id,
            )
        )
        await session.commit()

    async with AsyncClient(app=app, base_url="http://test") as c:
        resp = await c.post(
            "/api/v1/admin/auth/login",
            json={"email": email, "password": password},
        )
        assert resp.status_code == 200, f"Admin login failed: {resp.text}"
        token = resp.json()["access_token"]

    yield token

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("DELETE FROM admin_user_roles WHERE admin_user_id = :aid"),
            {"aid": admin_id},
        )
        await session.execute(
            text("DELETE FROM admin_users WHERE id = :aid"),
            {"aid": admin_id},
        )
        await session.commit()


@pytest.fixture
async def user_token():
    """Register a fresh test user, log in, yield (token, user_dict)."""
    suffix = unique_suffix()
    email = f"qa_user_{suffix}@wayntest.com"
    username = f"qa_{suffix}"
    password = "UserPass123!"
    user_id = None

    async with AsyncClient(app=app, base_url="http://test") as c:
        resp = await c.post(
            "/api/v1/auth/register",
            json={
                "email": email,
                "password": password,
                "full_name": "QA Test User",
                "username": username,
            },
        )
        assert resp.status_code == 201, f"Register failed: {resp.text}"
        data = resp.json()
        token = data["access_token"]

    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(User).where(User.email == email)
        )
        user = result.scalar_one()
        user_id = user.id

    yield token, data

    # Cleanup
    if user_id is not None:
        async with AsyncSessionLocal() as session:
            # Wallet transfers reference user_wallets via a RESTRICT
            # foreign key, so they must be removed before the user
            # (and their wallet) can be deleted.  This applies whether
            # the test user was the sender or the receiver.
            await session.execute(
                text(
                    """
                    DELETE FROM wallet_transfers
                    WHERE sender_wallet_id IN (
                        SELECT id FROM user_wallets
                        WHERE user_id = :uid
                    )
                    OR receiver_wallet_id IN (
                        SELECT id FROM user_wallets
                        WHERE user_id = :uid
                    )
                    """
                ),
                {"uid": user_id},
            )
            await session.execute(
                text("DELETE FROM users WHERE id = :uid"),
                {"uid": user_id},
            )
            await session.commit()


@pytest.fixture
async def test_category():
    """Create a test category via direct DB + admin API. Clean up after."""
    from app.core.security import create_access_token

    suffix = unique_suffix()
    cat_name_ar = f"اختبار_{suffix}"
    cat_name_en = f"Test_{suffix}"
    cat_id = None
    admin_id = None

    async with AsyncSessionLocal() as session:
        admin_email = f"qa_cat_admin_{suffix}@wayntest.com"
        admin_password = "AdminPass123!"
        admin = AdminUser(
            email=admin_email,
            password_hash=hash_password(admin_password),
            full_name="QA Cat Admin",
            is_active=True,
        )
        session.add(admin)
        await session.commit()
        await session.refresh(admin)
        admin_id = admin.id

        result = await session.execute(
            select(Role).where(Role.name == "super_admin")
        )
        super_admin_role = result.scalar_one()

        await session.execute(
            insert(admin_user_roles).values(
                admin_user_id=admin_id,
                role_id=super_admin_role.id,
            )
        )
        await session.commit()

        # Create category directly in DB to avoid dependency on API
        cat = Category(
            name_ar=cat_name_ar,
            name_en=cat_name_en,
            icon="test-icon",
            sort_order=999,
            is_active=True,
        )
        session.add(cat)
        await session.commit()
        await session.refresh(cat)
        cat_id = cat.id

    admin_token_val = create_access_token(
        subject=str(admin_id),
        token_type="admin",
    )

    yield {
        "id": cat_id,
        "name_ar": cat_name_ar,
        "name_en": cat_name_en,
    }, admin_token_val

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("DELETE FROM categories WHERE id = :cid"),
            {"cid": cat_id},
        )
        await session.execute(
            text("DELETE FROM admin_user_roles WHERE admin_user_id = :aid"),
            {"aid": admin_id},
        )
        await session.execute(
            text("DELETE FROM admin_users WHERE id = :aid"),
            {"aid": admin_id},
        )
        await session.commit()


@pytest.fixture
async def test_place(test_category, admin_token):
    """Create a test place via the admin API. Clean up after."""
    cat_data, _ = test_category
    cat_id = cat_data["id"]
    place_id = None

    async with AsyncClient(app=app, base_url="http://test") as c:
        resp = await c.post(
            "/api/v1/admin/places",
            json={
                "category_id": cat_id,
                "name": "مطعم تجريبي",
                "city": "طرابلس",
                "category_name": "مطاعم",
                "image_url": "https://example.com/test.jpg",
                "rating": 4.5,
                "is_open": True,
                "is_active": True,
                "description": "مطعم للاختبار",
                "address": "شارع النهضة",
                "phone": "+218 21 123 4567",
                "website": "https://example.com",
                "latitude": 32.8872,
                "longitude": 13.1913,
                "images": ["https://example.com/test.jpg"],
                "services": ["wifi", "parking"],
                "opening_time": "08:00",
                "closing_time": "23:00",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 201, f"Place create failed: {resp.text}"
        place_data = resp.json()
        place_id = place_data["id"]

    yield place_data

    # Cleanup
    if place_id is not None:
        async with AsyncSessionLocal() as session:
            await session.execute(
                text("DELETE FROM places WHERE id = :pid"),
                {"pid": place_id},
            )
            await session.commit()


@pytest.fixture
async def existing_category_id():
    """Return the ID of an existing 'مطاعم' category.

    Uses .first() instead of .scalar_one() because previous test runs
    may have created duplicate 'مطاعم' categories in the database.
    If missing, create required categories so dependent data tests are stable.
    """
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(Category).where(Category.name_ar == "مطاعم")
        )
        cat = result.scalars().first()
        created_here = []

        if not cat:
            cat = Category(
                name_ar="مطاعم",
                name_en="Restaurants",
                icon="restaurant",
                sort_order=1,
                is_active=True,
            )
            session.add(cat)
            await session.commit()
            await session.refresh(cat)
            created_here.append(cat.id)

        # Ensure at least one extra category exists for count expectations.
        count_result = await session.execute(
            text("SELECT COUNT(*) FROM categories")
        )
        categories_count = count_result.scalar_one()
        if categories_count < 2:
            extra = Category(
                name_ar="خدمات",
                name_en="Services",
                icon="services",
                sort_order=2,
                is_active=True,
            )
            session.add(extra)
            await session.commit()
            await session.refresh(extra)
            created_here.append(extra.id)

        try:
            yield cat.id
        finally:
            if created_here:
                async with AsyncSessionLocal() as cleanup:
                    for cid in created_here:
                        await cleanup.execute(
                            text("DELETE FROM categories WHERE id = :cid"),
                            {"cid": cid},
                        )
                    await cleanup.commit()


# ------------------------------------------------------------------
# Baseline data and per-test isolation
# ------------------------------------------------------------------


@pytest.fixture(autouse=True)
async def _reset_and_seed():
    """Reset test data and reseed baseline before each test."""
    async with AsyncSessionLocal() as session:
        async with session.begin():
            await session.execute(
                text(
                    """
                    TRUNCATE place_reviews, user_favorites, places, users,
                        admin_user_roles, admin_users, role_permissions,
                        permissions, roles, categories
                    RESTART IDENTITY CASCADE
                    """
                )
            )
        await session.commit()

    async with AsyncSessionLocal() as session:
        async with session.begin():
            await _ensure_baseline(session)
        await session.commit()

    yield


async def _ensure_baseline(session: AsyncSession) -> None:
    """Create minimal baseline rows required by tests if missing."""
    # Categories
    result = await session.execute(
        select(Category).where(Category.name_ar == "مطاعم")
    )
    restaurants = result.scalar_one_or_none()
    if not restaurants:
        restaurants = Category(
            name_ar="مطاعم",
            name_en="Restaurants",
            icon="restaurant",
            sort_order=1,
            is_active=True,
        )
        session.add(restaurants)
        await session.flush()

    result = await session.execute(
        select(Category).where(Category.name_ar == "خدمات")
    )
    services = result.scalar_one_or_none()
    if not services:
        services = Category(
            name_ar="خدمات",
            name_en="Services",
            icon="services",
            sort_order=2,
            is_active=True,
        )
        session.add(services)
        await session.flush()

    # Permissions
    permission_map = {}
    for name, desc in [
        ("users.read", "View users"),
        ("users.write", "Create and update users"),
        ("users.delete", "Delete users"),
        ("places.read", "View places"),
        ("places.write", "Create and update places"),
        ("places.delete", "Delete places"),
        ("categories.read", "View categories"),
        ("categories.write", "Create and update categories"),
        ("reports.read", "View reports"),
        ("reports.write", "Handle reports"),
    ]:
        result = await session.execute(
            select(Permission).where(Permission.name == name)
        )
        perm = result.scalar_one_or_none()
        if not perm:
            perm = Permission(name=name, description=desc)
            session.add(perm)
            await session.flush()
        permission_map[name] = perm

    # Roles
    role_map = {}
    for name, desc in [
        ("super_admin", "Full access to the WAYN administration system"),
        ("admin", "Administrative access"),
        ("moderator", "Moderation access"),
        ("editor", "Content editing access"),
    ]:
        result = await session.execute(select(Role).where(Role.name == name))
        role = result.scalar_one_or_none()
        if not role:
            role = Role(name=name, description=desc, is_active=True)
            session.add(role)
            await session.flush()
        role_map[name] = role

    # Role permissions for super_admin
    for perm_name in [
        "users.read",
        "users.write",
        "users.delete",
        "places.read",
        "places.write",
        "places.delete",
        "categories.read",
        "categories.write",
        "reports.read",
        "reports.write",
    ]:
        result = await session.execute(
            select(role_permissions).where(
                role_permissions.c.role_id == role_map["super_admin"].id,
                role_permissions.c.permission_id == permission_map[perm_name].id,
            )
        )
        if not result.first():
            await session.execute(
                insert(role_permissions).values(
                    role_id=role_map["super_admin"].id,
                    permission_id=permission_map[perm_name].id,
                )
            )

    # Role permissions for moderator
    for perm_name in [
        "users.read",
        "places.read",
        "reports.read",
        "reports.write",
    ]:
        result = await session.execute(
            select(role_permissions).where(
                role_permissions.c.role_id == role_map["moderator"].id,
                role_permissions.c.permission_id == permission_map[perm_name].id,
            )
        )
        if not result.first():
            await session.execute(
                insert(role_permissions).values(
                    role_id=role_map["moderator"].id,
                    permission_id=permission_map[perm_name].id,
                )
            )

    # Baseline admin user
    admin_email = "baseline_admin@wayntest.com"
    result = await session.execute(
        select(AdminUser).where(AdminUser.email == admin_email)
    )
    admin = result.scalar_one_or_none()
    if not admin:
        admin = AdminUser(
            email=admin_email,
            password_hash=hash_password("BaselineAdmin123!"),
            full_name="Baseline Admin",
            is_active=True,
        )
        session.add(admin)
        await session.flush()
        await session.execute(
            insert(admin_user_roles).values(
                admin_user_id=admin.id,
                role_id=role_map["super_admin"].id,
            )
        )

    # Baseline regular user
    user_email = "baseline_user@wayntest.com"
    result = await session.execute(select(User).where(User.email == user_email))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email=user_email,
            password_hash=hash_password("BaselineUser123!"),
            full_name="Baseline User",
            username="baseline_user",
            is_active=True,
        )
        session.add(user)
        await session.flush()