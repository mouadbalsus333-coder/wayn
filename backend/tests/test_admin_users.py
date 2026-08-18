"""Admin User Management API tests."""
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import insert, select, text

from app.core.database import AsyncSessionLocal
from app.core.security import create_access_token, hash_password
from app.models.admin_associations import admin_user_roles
from app.models.admin_user import AdminUser
from app.models.permission import Permission
from app.models.role import Role


def _uuid():
    return uuid.uuid4().hex[:10]


# ------------------------------------------------------------------
# Security
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_admin_users_without_auth(client):
    """Unauthenticated requests are rejected."""
    resp = await client.get("/api/v1/admin/users")
    assert resp.status_code in (401, 403)


@pytest.mark.anyio
async def test_list_admin_users_requires_super_admin(client):
    """Non-super-admin admin cannot list admin users."""
    suffix = _uuid()
    email = f"nonsa_list_{suffix}@wayntest.com"

    async with AsyncSessionLocal() as session:
        admin = AdminUser(
            email=email,
            password_hash=hash_password("TestPass123!"),
            full_name="Non SA Admin",
            is_active=True,
        )
        session.add(admin)
        await session.commit()
        await session.refresh(admin)
        admin_id = admin.id

        result = await session.execute(
            select(Role).where(Role.name == "admin")
        )
        admin_role = result.scalar_one()

        await session.execute(
            insert(admin_user_roles).values(
                admin_user_id=admin_id,
                role_id=admin_role.id,
            )
        )
        await session.commit()

    token = create_access_token(
        subject=str(admin_id),
        token_type="admin",
    )

    resp = await client.get(
        "/api/v1/admin/users",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 403

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text(
                "DELETE FROM admin_user_roles WHERE admin_user_id = :aid"
            ),
            {"aid": admin_id},
        )
        await session.execute(
            text("DELETE FROM admin_users WHERE id = :aid"),
            {"aid": admin_id},
        )
        await session.commit()


# ------------------------------------------------------------------
# List
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_admin_users(client, admin_token):
    """Super admin can list admin users."""
    resp = await client.get(
        "/api/v1/admin/users",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1  # baseline admin exists


# ------------------------------------------------------------------
# Create
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_create_admin_user_no_roles(
    client,
    admin_token,
):
    """New admin user is created without any roles or permissions."""
    suffix = _uuid()
    email = f"create_noroles_{suffix}@wayntest.com"

    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": email,
            "password": "TestPass123!",
            "full_name": "No Roles User",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["email"] == email
    assert data["is_active"] is True
    assert data["roles"] == []
    assert data["permissions"] == []

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("DELETE FROM admin_users WHERE email = :email"),
            {"email": email},
        )
        await session.commit()


@pytest.mark.anyio
async def test_create_admin_user_email_normalization(
    client,
    admin_token,
):
    """Email is normalized to lowercase."""
    suffix = _uuid()
    email = f"EMAIL_{suffix}@WAYNTEST.COM"

    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": email,
            "password": "TestPass123!",
            "full_name": "Normalization User",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 201
    assert resp.json()["email"] == email.lower()

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("DELETE FROM admin_users WHERE email = :email"),
            {"email": email.lower()},
        )
        await session.commit()


@pytest.mark.anyio
async def test_create_admin_user_with_role(
    client,
    admin_token,
):
    """New admin user can be created with a specific role (not super_admin)."""
    suffix = _uuid()
    email = f"create_role_{suffix}@wayntest.com"

    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(Role).where(Role.name == "moderator")
        )
        mod_role = result.scalar_one()
        mod_role_id = mod_role.id

    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": email,
            "password": "TestPass123!",
            "full_name": "Role User",
            "role_ids": [mod_role_id],
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert "moderator" in data["roles"]
    assert "super_admin" not in data["roles"]

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text(
                "DELETE FROM admin_user_roles "
                "WHERE admin_user_id IN "
                "(SELECT id FROM admin_users WHERE email = :email)"
            ),
            {"email": email},
        )
        await session.execute(
            text("DELETE FROM admin_users WHERE email = :email"),
            {"email": email},
        )
        await session.commit()


@pytest.mark.anyio
async def test_create_admin_user_invalid_role(
    client,
    admin_token,
):
    """Creating admin with non-existent role_id returns 400."""
    suffix = _uuid()

    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": f"invalid_role_{suffix}@wayntest.com",
            "password": "TestPass123!",
            "full_name": "Invalid Role User",
            "role_ids": [999999],
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 400


@pytest.mark.anyio
async def test_create_admin_user_duplicate_email(
    client,
    admin_token,
):
    """Creating admin with existing email returns 409."""
    suffix = _uuid()
    email = f"duplicate_{suffix}@wayntest.com"

    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": email,
            "password": "TestPass123!",
            "full_name": "First User",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 201

    # Same email, different case → still a conflict (normalized)
    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": email.upper(),
            "password": "TestPass123!",
            "full_name": "Second User",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 409

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("DELETE FROM admin_users WHERE email = :email"),
            {"email": email},
        )
        await session.commit()


# ------------------------------------------------------------------
# Get by ID
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_admin_user_by_id(
    client,
    admin_token,
):
    """Super admin can get admin user by ID."""
    suffix = _uuid()
    email = f"getid_{suffix}@wayntest.com"

    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": email,
            "password": "TestPass123!",
            "full_name": "Get By ID User",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    admin_id = resp.json()["id"]

    resp = await client.get(
        f"/api/v1/admin/users/{admin_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == admin_id
    assert data["email"] == email

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("DELETE FROM admin_users WHERE id = :id"),
            {"id": admin_id},
        )
        await session.commit()


@pytest.mark.anyio
async def test_get_admin_user_not_found(
    client,
    admin_token,
):
    """Getting non-existent admin user returns 404."""
    resp = await client.get(
        "/api/v1/admin/users/999999",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 404


# ------------------------------------------------------------------
# Update
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_update_admin_user(
    client,
    admin_token,
):
    """Super admin can update admin user full_name."""
    suffix = _uuid()
    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": f"update_{suffix}@wayntest.com",
            "password": "TestPass123!",
            "full_name": "Original Name",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    admin_id = resp.json()["id"]

    resp = await client.put(
        f"/api/v1/admin/users/{admin_id}",
        json={"full_name": "Updated Name"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["full_name"] == "Updated Name"

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("DELETE FROM admin_users WHERE id = :id"),
            {"id": admin_id},
        )
        await session.commit()


@pytest.mark.anyio
async def test_update_admin_user_password(
    client,
    admin_token,
):
    """Password can be updated and is hashed (not stored in plaintext)."""
    suffix = _uuid()
    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": f"pw_{suffix}@wayntest.com",
            "password": "OldPass123!",
            "full_name": "Password User",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    admin_id = resp.json()["id"]

    resp = await client.put(
        f"/api/v1/admin/users/{admin_id}",
        json={"password": "NewPass456!"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200

    # Verify password was hashed (not stored as plaintext)
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(AdminUser).where(AdminUser.id == admin_id)
        )
        user = result.scalar_one()
        assert user.password_hash != "NewPass456!"
        assert user.password_hash.startswith("$")  # bcrypt hash

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("DELETE FROM admin_users WHERE id = :id"),
            {"id": admin_id},
        )
        await session.commit()


# ------------------------------------------------------------------
# Activate / Deactivate
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_activate_deactivate_admin_user(
    client,
    admin_token,
):
    """Activate and deactivate work correctly."""
    suffix = _uuid()
    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": f"act_{suffix}@wayntest.com",
            "password": "TestPass123!",
            "full_name": "Act Deact User",
            "is_active": True,
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    admin_id = resp.json()["id"]

    # Deactivate
    resp = await client.patch(
        f"/api/v1/admin/users/{admin_id}/deactivate",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["is_active"] is False

    # Activate
    resp = await client.patch(
        f"/api/v1/admin/users/{admin_id}/activate",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["is_active"] is True

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("DELETE FROM admin_users WHERE id = :id"),
            {"id": admin_id},
        )
        await session.commit()


# ------------------------------------------------------------------
# Roles Management
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_and_manage_roles(
    client,
    admin_token,
):
    """Full role management: list, add, remove, replace."""
    suffix = _uuid()
    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": f"roles_{suffix}@wayntest.com",
            "password": "TestPass123!",
            "full_name": "Roles User",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    admin_id = resp.json()["id"]

    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(Role).where(Role.name == "moderator")
        )
        mod_role = result.scalar_one()
        result = await session.execute(
            select(Role).where(Role.name == "editor")
        )
        editor_role = result.scalar_one()

    # List roles (empty initially)
    resp = await client.get(
        f"/api/v1/admin/users/{admin_id}/roles",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert resp.json() == []

    # Add role
    resp = await client.post(
        f"/api/v1/admin/users/{admin_id}/roles/{mod_role.id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["name"] == "moderator"

    # Remove role
    resp = await client.delete(
        f"/api/v1/admin/users/{admin_id}/roles/{mod_role.id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert resp.json() == []

    # Replace roles (add both moderator and editor)
    resp = await client.put(
        f"/api/v1/admin/users/{admin_id}/roles",
        json={"role_ids": [mod_role.id, editor_role.id]},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert len(resp.json()) == 2

    # Replace roles again (replace with just editor)
    resp = await client.put(
        f"/api/v1/admin/users/{admin_id}/roles",
        json={"role_ids": [editor_role.id]},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["name"] == "editor"

    # Add invalid role_id
    resp = await client.post(
        f"/api/v1/admin/users/{admin_id}/roles/999999",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 400

    # Remove non-existent role (no error, just returns current list)
    resp = await client.delete(
        f"/api/v1/admin/users/{admin_id}/roles/999999",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200

    # Get roles for non-existent user
    resp = await client.get(
        "/api/v1/admin/users/999999/roles",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 404

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text(
                "DELETE FROM admin_user_roles "
                "WHERE admin_user_id IN "
                "(SELECT id FROM admin_users WHERE email = :email)"
            ),
            {"email": f"roles_{suffix}@wayntest.com"},
        )
        await session.execute(
            text(
                "DELETE FROM admin_users WHERE email = :email"
            ),
            {"email": f"roles_{suffix}@wayntest.com"},
        )
        await session.commit()


# ------------------------------------------------------------------
# Resolved Permissions
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_resolved_permissions(
    client,
    admin_token,
):
    """Resolved permissions = role permissions + direct permissions, deduplicated."""
    suffix = _uuid()

    # Get moderator role (has 4 permissions in test DB)
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(Role).where(Role.name == "moderator")
        )
        mod_role = result.scalar_one()
        result = await session.execute(
            select(Permission).where(Permission.name == "users.read")
        )
        users_read = result.scalar_one()
        result = await session.execute(
            select(Permission).where(Permission.name == "users.delete")
        )
        users_delete = result.scalar_one()

    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": f"resolved_{suffix}@wayntest.com",
            "password": "TestPass123!",
            "full_name": "Resolved Perms User",
            "role_ids": [mod_role.id],
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    admin_id = resp.json()["id"]

    # Step 1: Resolved permissions should only contain role permissions
    resp = await client.get(
        f"/api/v1/admin/users/{admin_id}/resolved-permissions",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    perm_names = {p["name"] for p in resp.json()}
    assert perm_names == {
        "users.read",
        "places.read",
        "reports.read",
        "reports.write",
    }

    # Step 2: Add a direct permission already in the role → no duplication
    resp = await client.post(
        f"/api/v1/admin/users/{admin_id}/permissions/{users_read.id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200

    resp = await client.get(
        f"/api/v1/admin/users/{admin_id}/resolved-permissions",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    perms = resp.json()
    perm_ids = [p["id"] for p in perms]
    assert len(perm_ids) == len(set(perm_ids)), "Duplicate permissions found"
    assert len(perms) == 4  # Still 4 (users.read deduplicated)

    # Step 3: Add a direct permission NOT in the role → resolved grows
    resp = await client.post(
        f"/api/v1/admin/users/{admin_id}/permissions/{users_delete.id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200

    resp = await client.get(
        f"/api/v1/admin/users/{admin_id}/resolved-permissions",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    perms = resp.json()
    perm_ids = [p["id"] for p in perms]
    assert len(perm_ids) == len(set(perm_ids)), "Duplicate permissions found"
    perm_names = {p["name"] for p in perms}
    assert "users.delete" in perm_names
    assert "users.read" in perm_names

    # Step 4: Remove the direct permission that was added in step 3
    resp = await client.delete(
        f"/api/v1/admin/users/{admin_id}/permissions/{users_delete.id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200

    resp = await client.get(
        f"/api/v1/admin/users/{admin_id}/resolved-permissions",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    perm_names = {p["name"] for p in resp.json()}
    assert "users.delete" not in perm_names
    assert "users.read" in perm_names

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text(
                "DELETE FROM admin_user_permissions "
                "WHERE admin_user_id IN "
                "(SELECT id FROM admin_users WHERE email = :email)"
            ),
            {"email": f"resolved_{suffix}@wayntest.com"},
        )
        await session.execute(
            text(
                "DELETE FROM admin_user_roles "
                "WHERE admin_user_id IN "
                "(SELECT id FROM admin_users WHERE email = :email)"
            ),
            {"email": f"resolved_{suffix}@wayntest.com"},
        )
        await session.execute(
            text("DELETE FROM admin_users WHERE email = :email"),
            {"email": f"resolved_{suffix}@wayntest.com"},
        )
        await session.commit()


@pytest.mark.anyio
async def test_resolved_permissions_user_not_found(
    client,
    admin_token,
):
    """Resolved permissions for non-existent user returns 404."""
    resp = await client.get(
        "/api/v1/admin/users/999999/resolved-permissions",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 404


# ------------------------------------------------------------------
# Regression: Direct permissions still work
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_direct_permissions_still_work(
    client,
    admin_token,
):
    """Verify the existing direct permission endpoints still function."""
    suffix = _uuid()
    resp = await client.post(
        "/api/v1/admin/users",
        json={
            "email": f"regression_{suffix}@wayntest.com",
            "password": "TestPass123!",
            "full_name": "Regression User",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    admin_id = resp.json()["id"]

    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(Permission).where(Permission.name == "users.read")
        )
        perm = result.scalar_one()

    # Add direct permission
    resp = await client.post(
        f"/api/v1/admin/users/{admin_id}/permissions/{perm.id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert any(p["name"] == "users.read" for p in resp.json())

    # List direct permissions
    resp = await client.get(
        f"/api/v1/admin/users/{admin_id}/permissions",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["name"] == "users.read"

    # Replace direct permissions (empty list)
    resp = await client.put(
        f"/api/v1/admin/users/{admin_id}/permissions",
        json={"permission_ids": []},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert resp.json() == []

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text(
                "DELETE FROM admin_user_permissions "
                "WHERE admin_user_id IN "
                "(SELECT id FROM admin_users WHERE email = :email)"
            ),
            {"email": f"regression_{suffix}@wayntest.com"},
        )
        await session.execute(
            text("DELETE FROM admin_users WHERE email = :email"),
            {"email": f"regression_{suffix}@wayntest.com"},
        )
        await session.commit()
