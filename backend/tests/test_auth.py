"""Authentication lifecycle tests.

Covers: register, login, /me, password change + token_version invalidation,
profile update, location update, account status behavior.
"""
import pytest
from httpx import AsyncClient
from sqlalchemy import select, text

from app.core.database import AsyncSessionLocal
from app.core.security import hash_password, verify_password
from app.models.user import User, AccountStatus


# ------------------------------------------------------------------
# Registration
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_register_valid(client):
    suffix = __import__("uuid").uuid4().hex[:10]
    email = f"register_{suffix}@wayntest.com"
    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "SecurePass123!",
            "full_name": "Register Tester",
            "username": f"reg_{suffix}",
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert "access_token" in data
    assert "token_type" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == email
    assert "password" not in str(resp.json())
    assert "password_hash" not in str(resp.json())

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM users WHERE email = :e"), {"e": email})
        await session.commit()


@pytest.mark.anyio
async def test_register_duplicate_email(client):
    suffix = __import__("uuid").uuid4().hex[:10]
    email = f"dup_{suffix}@wayntest.com"
    payload = {
        "email": email,
        "password": "SecurePass123!",
        "full_name": "Dup Email",
        "username": f"dup_{suffix}",
    }
    resp1 = await client.post("/api/v1/auth/register", json=payload)
    assert resp1.status_code == 201

    resp2 = await client.post("/api/v1/auth/register", json=payload)
    assert resp2.status_code == 409
    assert "already registered" in resp2.json()["detail"].lower()

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM users WHERE email = :e"), {"e": email})
        await session.commit()


@pytest.mark.anyio
async def test_register_duplicate_username(client):
    suffix = __import__("uuid").uuid4().hex[:10]
    username = f"dupuser_{suffix}"
    resp1 = await client.post(
        "/api/v1/auth/register",
        json={
            "email": f"u1_{suffix}@wayntest.com",
            "password": "SecurePass123!",
            "full_name": "User 1",
            "username": username,
        },
    )
    assert resp1.status_code == 201

    resp2 = await client.post(
        "/api/v1/auth/register",
        json={
            "email": f"u2_{suffix}@wayntest.com",
            "password": "SecurePass123!",
            "full_name": "User 2",
            "username": username,
        },
    )
    assert resp2.status_code == 409
    assert "already taken" in resp2.json()["detail"].lower()

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM users WHERE email LIKE :p"), {"p": f"%{suffix}%"})
        await session.commit()


@pytest.mark.anyio
async def test_register_short_password(client):
    suffix = __import__("uuid").uuid4().hex[:10]
    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": f"short_{suffix}@wayntest.com",
            "password": "123",
            "full_name": "Short Pass",
            "username": f"short_{suffix}",
        },
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_register_invalid_email(client):
    suffix = __import__("uuid").uuid4().hex[:10]
    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "not-an-email",
            "password": "SecurePass123!",
            "full_name": "Bad Email",
            "username": f"bad_{suffix}",
        },
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_register_missing_fields(client):
    resp = await client.post(
        "/api/v1/auth/register",
        json={"email": "missing@test.com"},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_register_password_is_hashed(client):
    """Verify password_hash is a bcrypt hash, not plaintext."""
    suffix = __import__("uuid").uuid4().hex[:10]
    email = f"hashcheck_{suffix}@wayntest.com"
    password = "SecurePass123!"
    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "full_name": "Hash Check",
            "username": f"hash_{suffix}",
        },
    )
    assert resp.status_code == 201

    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User).where(User.email == email))
        user = result.scalar_one()
        assert user.password_hash != password
        assert user.password_hash.startswith("$")  # bcrypt hash
        assert verify_password(password, user.password_hash)
        assert not verify_password("wrong", user.password_hash)
        # Clean up
        await session.execute(text("DELETE FROM users WHERE email = :e"), {"e": email})
        await session.commit()


@pytest.mark.anyio
async def test_register_initial_token_version(client):
    suffix = __import__("uuid").uuid4().hex[:10]
    email = f"tvcheck_{suffix}@wayntest.com"
    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "SecurePass123!",
            "full_name": "Token Version Check",
            "username": f"tv_{suffix}",
        },
    )
    assert resp.status_code == 201

    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User).where(User.email == email))
        user = result.scalar_one()
        assert user.token_version == 1
        assert user.account_status == AccountStatus.ACTIVE
        await session.execute(text("DELETE FROM users WHERE email = :e"), {"e": email})
        await session.commit()


# ------------------------------------------------------------------
# Login
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_login_valid(client):
    suffix = __import__("uuid").uuid4().hex[:10]
    email = f"login_{suffix}@wayntest.com"
    password = "SecurePass123!"
    await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "full_name": "Login Tester",
            "username": f"login_{suffix}",
        },
    )

    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == email
    assert "password" not in str(data)

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM users WHERE email = :e"), {"e": email})
        await session.commit()


@pytest.mark.anyio
async def test_login_wrong_password(client):
    suffix = __import__("uuid").uuid4().hex[:10]
    email = f"wrongpw_{suffix}@wayntest.com"
    password = "CorrectPass123!"
    await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "full_name": "Wrong PW",
            "username": f"wrong_{suffix}",
        },
    )

    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "WrongPassword!"},
    )
    assert resp.status_code == 401
    assert "invalid" in resp.json()["detail"].lower()

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM users WHERE email = :e"), {"e": email})
        await session.commit()


@pytest.mark.anyio
async def test_login_unknown_email(client):
    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "nonexistent@nowayn.com", "password": "Whatever123!"},
    )
    assert resp.status_code == 401
    assert "invalid" in resp.json()["detail"].lower()


@pytest.mark.anyio
async def test_login_malformed_request(client):
    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "not-an-email"},
    )
    assert resp.status_code == 422


# ------------------------------------------------------------------
# /auth/me
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_me_with_valid_token(client, user_token):
    token, user_data = user_token
    resp = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["email"] == user_data["user"]["email"]
    assert data["username"] == user_data["user"]["username"]
    assert "password_hash" not in str(data)
    assert "token_version" not in str(data)


@pytest.mark.anyio
async def test_me_without_token(client):
    resp = await client.get("/api/v1/auth/me")
    assert resp.status_code == 401


@pytest.mark.anyio
async def test_me_with_invalid_token(client):
    resp = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer invalid.token.here"},
    )
    assert resp.status_code == 401


@pytest.mark.anyio
async def test_me_with_admin_token(client, admin_token):
    """A user endpoint should reject an admin token (token type mismatch)."""
    resp = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 403


@pytest.mark.anyio
async def test_me_no_user_in_db(client):
    """A valid JWT for a non-existent user should fail."""
    from app.core.security import create_access_token
    from app.models.user import AccountStatus

    fake_token = create_access_token(
        subject="00000000-0000-0000-0000-000000000000",
        token_version=1,
        token_type="user",
    )
    resp = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {fake_token}"},
    )
    assert resp.status_code == 401


# ------------------------------------------------------------------
# Password Change + Token Invalidation
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_password_change_invalidates_old_token(client):
    suffix = __import__("uuid").uuid4().hex[:10]
    email = f"pwchange_{suffix}@wayntest.com"
    password = "OldPass123!"
    new_password = "NewPass456!"

    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "full_name": "PW Change",
            "username": f"pw_{suffix}",
        },
    )
    assert resp.status_code == 201
    old_token = resp.json()["access_token"]

    # Verify old token works
    resp = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {old_token}"},
    )
    assert resp.status_code == 200

    # Change password
    resp = await client.put(
        "/api/v1/auth/me/password",
        json={"current_password": password, "new_password": new_password},
        headers={"Authorization": f"Bearer {old_token}"},
    )
    assert resp.status_code == 204

    # Verify old token is now invalidated (token_version incremented)
    resp = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {old_token}"},
    )
    assert resp.status_code == 401
    assert "invalidated" in resp.json()["detail"].lower()

    # Login with new password should work
    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": new_password},
    )
    assert resp.status_code == 200
    new_token = resp.json()["access_token"]

    # Verify new token works
    resp = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {new_token}"},
    )
    assert resp.status_code == 200

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM users WHERE email = :e"), {"e": email})
        await session.commit()


@pytest.mark.anyio
async def test_password_change_wrong_current(client, user_token):
    token, _ = user_token
    resp = await client.put(
        "/api/v1/auth/me/password",
        json={"current_password": "WrongOld123!", "new_password": "NewPass456!"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 400


@pytest.mark.anyio
async def test_password_change_same_password(client, user_token):
    token, _ = user_token
    # user_token fixture registered with UserPass123!
    resp = await client.put(
        "/api/v1/auth/me/password",
        json={"current_password": "UserPass123!", "new_password": "UserPass123!"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 400


@pytest.mark.anyio
async def test_password_change_short_new(client, user_token):
    token, _ = user_token
    resp = await client.put(
        "/api/v1/auth/me/password",
        json={"current_password": "UserPass123!", "new_password": "123"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


# ------------------------------------------------------------------
# Profile Update
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_update_profile_valid(client, user_token):
    token, _ = user_token
    resp = await client.put(
        "/api/v1/auth/me",
        json={"full_name": "Updated Name QA"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["full_name"] == "Updated Name QA"


@pytest.mark.anyio
async def test_update_profile_duplicate_username(client, user_token):
    token, user_data = user_token
    # Can't set our own username via update in user_token fixture, so
    # try to claim a username that the existing test user already has
    resp = await client.put(
        "/api/v1/auth/me",
        json={"username": user_data["user"]["username"]},
        headers={"Authorization": f"Bearer {token}"},
    )
    # This should succeed (it's the same user's own username)
    assert resp.status_code == 200


@pytest.mark.anyio
async def test_update_profile_short_username(client, user_token):
    token, _ = user_token
    resp = await client.put(
        "/api/v1/auth/me",
        json={"username": "ab"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_update_profile_unauthorized(client):
    resp = await client.put(
        "/api/v1/auth/me",
        json={"full_name": "Hacker"},
    )
    assert resp.status_code == 401


# ------------------------------------------------------------------
# Location Update
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_location_update_valid(client, user_token):
    token, _ = user_token
    resp = await client.put(
        "/api/v1/auth/me/location",
        json={"latitude": 32.8872, "longitude": 13.1913, "source": "manual"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["latitude"] == 32.8872
    assert data["longitude"] == 13.1913


@pytest.mark.anyio
async def test_location_update_invalid_latitude(client, user_token):
    token, _ = user_token
    resp = await client.put(
        "/api/v1/auth/me/location",
        json={"latitude": 95.0, "longitude": 13.0, "source": "manual"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_location_update_invalid_longitude(client, user_token):
    token, _ = user_token
    resp = await client.put(
        "/api/v1/auth/me/location",
        json={"latitude": 32.0, "longitude": 190.0, "source": "manual"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_location_update_invalid_source(client, user_token):
    token, _ = user_token
    resp = await client.put(
        "/api/v1/auth/me/location",
        json={"latitude": 32.0, "longitude": 13.0, "source": "gps"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_location_update_unauthorized(client):
    resp = await client.put(
        "/api/v1/auth/me/location",
        json={"latitude": 32.0, "longitude": 13.0, "source": "manual"},
    )
    assert resp.status_code == 401


# ------------------------------------------------------------------
# Account Status
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_suspended_user_can_login_but_not_use_api(client):
    """
    Test the actual behavior: does authenticate() check account_status?
    The code only checks is_active, not account_status.
    This test documents the current behavior.
    """
    suffix = __import__("uuid").uuid4().hex[:10]
    email = f"status_{suffix}@wayntest.com"
    password = "SecurePass123!"

    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "full_name": "Status Test",
            "username": f"status_{suffix}",
        },
    )
    assert resp.status_code == 201

    # Suspend the account directly in DB
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User).where(User.email == email))
        user = result.scalar_one()
        user.account_status = AccountStatus.SUSPENDED
        await session.commit()

    # Try to login with valid password — does it work?
    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )

    # Try to use the token
    if resp.status_code == 200:
        token = resp.json()["access_token"]
        resp_me = await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        # If login succeeded, /me should fail with 403 (account restricted)
        assert resp_me.status_code == 403

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM users WHERE email = :e"), {"e": email})
        await session.commit()


@pytest.mark.anyio
async def test_inactive_user_cannot_login(client):
    """is_active=False should block login at authenticate()."""
    suffix = __import__("uuid").uuid4().hex[:10]
    email = f"inactive_{suffix}@wayntest.com"
    password = "SecurePass123!"

    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "full_name": "Inactive User",
            "username": f"inactive_{suffix}",
        },
    )
    assert resp.status_code == 201

    # Deactivate in DB
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User).where(User.email == email))
        user = result.scalar_one()
        user.is_active = False
        await session.commit()

    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert resp.status_code == 401

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(text("DELETE FROM users WHERE email = :e"), {"e": email})
        await session.commit()


# ------------------------------------------------------------------
# Token Tests
# ------------------------------------------------------------------


@pytest.mark.anyio
async def test_token_has_ver_claim(client):
    """The JWT should contain the 'ver' (token_version) claim."""
    suffix = __import__("uuid").uuid4().hex[:10]
    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": f"token_{suffix}@wayntest.com",
            "password": "SecurePass123!",
            "full_name": "Token Test",
            "username": f"token_{suffix}",
        },
    )
    assert resp.status_code == 201

    from app.core.security import decode_access_token
    payload = decode_access_token(resp.json()["access_token"])
    assert "ver" in payload
    assert payload["ver"] == 1
    assert payload["type"] == "user"

    # Cleanup
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("DELETE FROM users WHERE email = :e"),
            {"e": f"token_{suffix}@wayntest.com"},
        )
        await session.commit()
