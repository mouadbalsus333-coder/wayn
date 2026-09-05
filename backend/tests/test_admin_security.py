import asyncio
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import httpx
from jose import jwt
from sqlalchemy import delete, insert, select, update

from app.core.config import settings
from app.core.database import AsyncSessionLocal, engine
from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
)
from app.main import app
from app.models.admin_associations import (
    admin_user_permissions,
    admin_user_roles,
)
from app.models.admin_user import AdminUser
from app.models.permission import Permission
from app.models.role import Role


def _run(coroutine):
    async def run_and_dispose():
        try:
            return await coroutine
        finally:
            await engine.dispose()

    return asyncio.run(run_and_dispose())


async def _create_admin(*, is_active: bool = True) -> AdminUser:
    async with AsyncSessionLocal() as session:
        admin = AdminUser(
            email=f"step1-{uuid4()}@example.com",
            password_hash=hash_password("AdminPassword123!"),
            full_name="STEP 1 Admin",
            is_active=is_active,
        )
        session.add(admin)
        await session.commit()
        await session.refresh(admin)
        return admin


async def _delete_admin(admin_id: int) -> None:
    async with AsyncSessionLocal() as session:
        await session.execute(
            delete(AdminUser).where(AdminUser.id == admin_id)
        )
        await session.commit()


async def _create_admin_with_permissions(
    permission_names: list[str],
    *,
    super_admin: bool = False,
) -> AdminUser:
    admin = await _create_admin()
    async with AsyncSessionLocal() as session:
        for permission_name in permission_names:
            permission = (
                await session.execute(
                    select(Permission).where(
                        Permission.name == permission_name
                    )
                )
            ).scalar_one_or_none()
            if permission is None:
                permission = Permission(
                    name=permission_name,
                    description="STEP 2 test permission",
                )
                session.add(permission)
                await session.flush()
            await session.execute(
                insert(admin_user_permissions).values(
                    admin_user_id=admin.id,
                    permission_id=permission.id,
                )
            )

        if super_admin:
            role = (
                await session.execute(
                    select(Role).where(Role.name == "super_admin")
                )
            ).scalar_one()
            await session.execute(
                insert(admin_user_roles).values(
                    admin_user_id=admin.id,
                    role_id=role.id,
                )
            )
        await session.commit()
    return admin


async def _client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://testserver",
    )


async def _web_login_and_logout() -> None:
    admin = await _create_admin()

    try:
        async with await _client() as client:
            bearer_login = await client.post(
                "/api/v1/admin/auth/login",
                json={
                    "email": admin.email,
                    "password": "AdminPassword123!",
                },
            )
            assert bearer_login.status_code == 200
            bearer_token = bearer_login.json()["access_token"]
            assert decode_access_token(bearer_token)["type"] == "admin"

            login = await client.post(
                "/api/v1/admin/auth/web-login",
                json={
                    "email": admin.email,
                    "password": "AdminPassword123!",
                },
                headers={"Origin": "http://localhost:5173"},
            )

            assert login.status_code == 200
            assert "access_token" not in login.json()
            set_cookie = login.headers["set-cookie"].lower()
            assert "wayn_admin_session=" in set_cookie
            assert "httponly" in set_cookie
            assert "samesite=strict" in set_cookie

            me = await client.get("/api/v1/admin/auth/me")
            assert me.status_code == 200
            assert me.json()["admin_id"] == admin.id
            assert me.json()["roles"] == []
            assert me.json()["permissions"] == []

            logout = await client.post(
                "/api/v1/admin/auth/logout",
                headers={"Origin": "http://localhost:5173"},
            )
            assert logout.status_code == 204
            assert "max-age=0" in logout.headers["set-cookie"].lower()

            after_logout = await client.get(
                "/api/v1/admin/auth/me"
            )
            assert after_logout.status_code == 401

            old_bearer = await client.get(
                "/api/v1/admin/auth/me",
                headers={"Authorization": f"Bearer {bearer_token}"},
            )
            assert old_bearer.status_code == 401
    finally:
        await _delete_admin(admin.id)


def test_web_login_cookie_me_and_logout():
    _run(_web_login_and_logout())


async def _authentication_failures() -> None:
    inactive = await _create_admin(is_active=False)

    try:
        async with await _client() as client:
            wrong_password = await client.post(
                "/api/v1/admin/auth/web-login",
                json={
                    "email": inactive.email,
                    "password": "wrong-password",
                },
            )
            assert wrong_password.status_code == 401

            inactive_response = await client.post(
                "/api/v1/admin/auth/web-login",
                json={
                    "email": inactive.email,
                    "password": "AdminPassword123!",
                },
            )
            assert inactive_response.status_code == 403

            invalid_token = await client.get(
                "/api/v1/admin/auth/me",
                headers={"Authorization": "Bearer invalid"},
            )
            assert invalid_token.status_code == 401

            expired_token = jwt.encode(
                {
                    "sub": str(inactive.id),
                    "ver": inactive.token_version,
                    "type": "admin",
                    "exp": datetime.now(timezone.utc)
                    - timedelta(minutes=1),
                },
                settings.jwt_secret_key,
                algorithm=settings.jwt_algorithm,
            )
            expired = await client.get(
                "/api/v1/admin/auth/me",
                headers={"Authorization": f"Bearer {expired_token}"},
            )
            assert expired.status_code == 401

            user_token = create_access_token(
                subject="1",
                token_type="user",
            )
            wrong_type = await client.get(
                "/api/v1/admin/auth/me",
                headers={"Authorization": f"Bearer {user_token}"},
            )
            assert wrong_type.status_code == 401
    finally:
        await _delete_admin(inactive.id)


def test_admin_authentication_failures():
    _run(_authentication_failures())


async def _token_version_invalidation() -> None:
    admin = await _create_admin()

    try:
        token = create_access_token(
            subject=str(admin.id),
            token_version=admin.token_version,
            token_type="admin",
        )

        async with AsyncSessionLocal() as session:
            await session.execute(
                update(AdminUser)
                .where(AdminUser.id == admin.id)
                .values(token_version=AdminUser.token_version + 1)
            )
            await session.commit()

        async with await _client() as client:
            response = await client.get(
                "/api/v1/admin/auth/me",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert response.status_code == 401
            assert response.json()["detail"] == "Session has been invalidated"
    finally:
        await _delete_admin(admin.id)


def test_admin_token_version_invalidation():
    _run(_token_version_invalidation())


async def _permissions_are_loaded_from_database() -> None:
    admin = await _create_admin()
    permission_name = f"step1.{uuid4()}"

    async with AsyncSessionLocal() as session:
        permission = Permission(
            name=permission_name,
            description="STEP 1 test permission",
        )
        session.add(permission)
        await session.flush()
        await session.execute(
            insert(admin_user_permissions).values(
                admin_user_id=admin.id,
                permission_id=permission.id,
            )
        )
        await session.commit()

    try:
        token = create_access_token(
            subject=str(admin.id),
            token_version=admin.token_version,
            token_type="admin",
        )

        async with await _client() as client:
            response = await client.get(
                "/api/v1/admin/auth/me",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert response.status_code == 200
            assert response.json()["permissions"] == [permission_name]

            forbidden = await client.get(
                "/api/v1/admin/auth/test-permission",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert forbidden.status_code == 403
    finally:
        async with AsyncSessionLocal() as session:
            await session.execute(
                delete(Permission).where(
                    Permission.name == permission_name
                )
            )
            await session.commit()
        await _delete_admin(admin.id)


def test_admin_permissions_are_loaded_from_database():
    _run(_permissions_are_loaded_from_database())


async def _csrf_and_cors() -> None:
    admin = await _create_admin()

    try:
        async with await _client() as client:
            await client.post(
                "/api/v1/admin/auth/web-login",
                json={
                    "email": admin.email,
                    "password": "AdminPassword123!",
                },
            )

            rejected = await client.post(
                "/api/v1/admin/auth/logout",
                headers={"Origin": "https://evil.example"},
            )
            assert rejected.status_code == 403

            preflight = await client.options(
                "/api/v1/admin/auth/web-login",
                headers={
                    "Origin": "http://localhost:5173",
                    "Access-Control-Request-Method": "POST",
                },
            )
            assert preflight.status_code == 200
            assert preflight.headers["access-control-allow-origin"] == (
                "http://localhost:5173"
            )
            assert preflight.headers["access-control-allow-credentials"] == (
                "true"
            )
    finally:
        await _delete_admin(admin.id)


def test_cookie_origin_validation_and_explicit_cors():
    _run(_csrf_and_cors())


async def _admin_api_contracts() -> None:
    admin = await _create_admin_with_permissions(
        [
            "users.read",
            "places.read",
            "community.read",
            "community.moderate",
            "reviews.read",
            "reviews.moderate",
            "wallet.read",
            "categories.delete",
        ]
    )
    super_admin = await _create_admin_with_permissions(
        [],
        super_admin=True,
    )

    try:
        token = create_access_token(
            subject=str(admin.id),
            token_version=admin.token_version,
            token_type="admin",
        )
        super_token = create_access_token(
            subject=str(super_admin.id),
            token_version=super_admin.token_version,
            token_type="admin",
        )
        headers = {"Authorization": f"Bearer {token}"}
        super_headers = {"Authorization": f"Bearer {super_token}"}

        async with await _client() as client:
            no_auth = await client.get(
                "/api/v1/admin/dashboard/summary"
            )
            assert no_auth.status_code == 401

            summary = await client.get(
                "/api/v1/admin/dashboard/summary",
                headers=headers,
            )
            assert summary.status_code == 200
            assert summary.json()["total_users"] is not None
            assert summary.json()["visible_reviews"] is not None

            places = await client.get(
                "/api/v1/admin/places?page=1&limit=1&sort_by=name&sort_order=asc",
                headers=headers,
            )
            assert places.status_code == 200
            assert set(places.json()) == {
                "items",
                "total",
                "page",
                "limit",
                "pages",
            }

            admin_users = await client.get(
                "/api/v1/admin/users?page=1&limit=1",
                headers=super_headers,
            )
            assert admin_users.status_code == 200
            assert admin_users.json()["page"] == 1
            assert admin_users.json()["limit"] == 1

            regular_admin_forbidden = await client.get(
                "/api/v1/admin/users",
                headers=headers,
            )
            assert regular_admin_forbidden.status_code == 403

            regular_users = await client.get(
                "/api/v1/admin/regular-users?page=1&limit=1&sort_by=points",
                headers=headers,
            )
            assert regular_users.status_code == 200
            assert regular_users.json()["limit"] == 1

            regular_status_forbidden = await client.patch(
                f"/api/v1/admin/regular-users/{uuid4()}/status",
                headers=headers,
                json={"is_active": False},
            )
            assert regular_status_forbidden.status_code == 403

            community = await client.get(
                "/api/v1/admin/community/posts?page=1&limit=1",
                headers=headers,
            )
            assert community.status_code == 200

            hidden_post = await client.patch(
                f"/api/v1/admin/community/posts/{uuid4()}/visibility",
                headers=headers,
                json={"is_visible": False},
            )
            assert hidden_post.status_code == 404

            hidden_comment = await client.patch(
                f"/api/v1/admin/community/comments/{uuid4()}/visibility",
                headers=headers,
                json={"is_visible": False},
            )
            assert hidden_comment.status_code == 404

            reviews = await client.get(
                "/api/v1/admin/reviews?page=1&limit=1&is_visible=true",
                headers=headers,
            )
            assert reviews.status_code == 200

            hidden_review = await client.patch(
                f"/api/v1/admin/reviews/{uuid4()}/visibility",
                headers=headers,
                json={"is_visible": False},
            )
            assert hidden_review.status_code == 404

            wallet_read = await client.get(
                "/api/v1/admin/wallet/lookup",
                headers=headers,
            )
            assert wallet_read.status_code == 400

            wallet_recharge = await client.post(
                "/api/v1/admin/wallet/recharge",
                headers=headers,
                json={
                    "target_user_id": str(uuid4()),
                    "amount": 1,
                },
            )
            assert wallet_recharge.status_code == 403

            category_delete = await client.delete(
                f"/api/v1/admin/categories/{uuid4()}",
                headers=headers,
            )
            assert category_delete.status_code == 404

            write_only = await _create_admin_with_permissions(
                ["categories.write"]
            )
            write_token = create_access_token(
                subject=str(write_only.id),
                token_version=write_only.token_version,
                token_type="admin",
            )
            forbidden_delete = await client.delete(
                f"/api/v1/admin/categories/{uuid4()}",
                headers={"Authorization": f"Bearer {write_token}"},
            )
            assert forbidden_delete.status_code == 403
            await _delete_admin(write_only.id)
    finally:
        await _delete_admin(admin.id)
        await _delete_admin(super_admin.id)


def test_admin_api_contracts_and_permission_split():
    _run(_admin_api_contracts())