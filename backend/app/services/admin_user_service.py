from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import get_admin_permissions
from app.core.security import hash_password
from app.models.admin_user import AdminUser
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User
from app.repositories.admin_user_repository import AdminUserRepository
from app.repositories.role_repository import RoleRepository
from app.schemas.admin_user import (
    AdminUserCreate,
    AdminUserRead,
    AdminUserUpdate,
)
from app.services.wallet.service import WalletService


class AdminUserService:
    def __init__(
        self,
        admin_user_repository: AdminUserRepository,
        role_repository: RoleRepository,
        session: AsyncSession,
    ):
        self.admin_user_repository = admin_user_repository
        self.role_repository = role_repository
        self.session = session

    def _to_read(
        self,
        admin_user: AdminUser,
    ) -> AdminUserRead:
        role_names = sorted(
            {
                role.name
                for role in admin_user.roles
                if role.is_active
            }
        )

        permission_names = sorted(
            get_admin_permissions(admin_user)
        )

        return AdminUserRead(
            id=admin_user.id,
            email=admin_user.email,
            full_name=admin_user.full_name,
            is_active=admin_user.is_active,
            roles=role_names,
            permissions=permission_names,
        )

    async def list_admin_users(self) -> list[AdminUserRead]:
        users = await self.admin_user_repository.list_admin_users()

        return [self._to_read(user) for user in users]

    async def get_admin_user(
        self,
        admin_user_id: int,
    ) -> AdminUserRead | None:
        user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if user is None:
            return None

        return self._to_read(user)

    async def _generate_username(self, email: str) -> str:
        """Derive a unique, valid ``users.username`` from an email.

        The regular ``users`` table requires a unique username, which
        the admin account model does not have. We derive one from the
        email's local part and append a numeric suffix when taken.
        """

        base = "".join(
            character
            if character.isalnum() or character in "._-"
            else "_"
            for character in email.split("@", 1)[0]
        ).strip("._-")

        if not base:
            base = "admin"

        base = base[:45]
        username = base

        suffix = 1

        while (
            await self.session.execute(
                select(User).where(User.username == username)
            )
        ).scalar_one_or_none() is not None:
            suffix += 1
            username = f"{base}{suffix}"

        return username

    async def create_admin_user(
        self,
        data: AdminUserCreate,
    ) -> AdminUserRead:
        normalized_email = data.email.lower()

        existing = await self.admin_user_repository.get_by_email(
            normalized_email
        )

        if existing is not None:
            raise ValueError(
                "Admin user with this email already exists"
            )

        password_hash = hash_password(data.password)

        # =========================================================
        # Keep the regular ``users`` account in sync so the admin
        # can sign in from the normal WAYN login screen. The two
        # identity stores are linked by email (no foreign key).
        # =========================================================
        user_result = await self.session.execute(
            select(User).where(User.email == normalized_email)
        )
        user = user_result.scalar_one_or_none()

        if user is None:
            # No regular account yet: create one inside the SAME
            # transaction (no commit here — the AdminUser repository
            # commits both rows atomically).
            user = User(
                email=normalized_email,
                password_hash=password_hash,
                full_name=data.full_name,
                username=await self._generate_username(
                    normalized_email
                ),
                is_active=True,
                # The account is created by a Super Admin, so it must
                # be able to log in immediately without an email
                # verification round-trip.
                is_verified=True,
            )

            self.session.add(user)

            # Flush so the database-generated user ID exists before
            # the wallet is created after the commit.
            await self.session.flush()
        else:
            # An account with this email already exists as a regular
            # user. Creating an admin must never silently overwrite
            # the user's credentials or status. Upgrading an existing
            # user to admin should be a separate, explicit operation.
            raise ValueError(
                "هذا البريد مرتبط بحساب مستخدم موجود بالفعل. "
                "يجب استخدام حساب جديد أو تنفيذ ترقية الحساب "
                "من مسار منفصل."
            )

        admin_user = AdminUser(
            email=normalized_email,
            password_hash=password_hash,
            full_name=data.full_name,
            is_active=data.is_active,
        )

        admin_user = await self.admin_user_repository.create_admin_user(
            admin_user
        )

        # The admin repository committed the transaction (User +
        # AdminUser atomically). Now create the user's wallet, which
        # manages its own transaction.
        if user.id is not None:
            await WalletService(self.session).get_or_create_wallet(
                user.id
            )

        role_ids = data.role_ids or []

        if role_ids:
            unique_role_ids = list(dict.fromkeys(role_ids))

            for role_id in unique_role_ids:
                role = await self.role_repository.get_role(role_id)

                if role is None:
                    raise ValueError(
                        f"Role {role_id} not found"
                    )

            await self.admin_user_repository.replace_user_roles(
                admin_user.id,
                unique_role_ids,
            )

        # Assign direct permissions atomically in the same flow
        permission_ids = data.permission_ids or []
        if permission_ids:
            unique_permission_ids = list(dict.fromkeys(permission_ids))

            for permission_id in unique_permission_ids:
                permission = await self.admin_user_repository.get_permission(
                    permission_id
                )

                if permission is None:
                    raise ValueError(
                        f"Permission {permission_id} not found"
                    )

            await self.admin_user_repository.replace_user_permissions(
                admin_user.id,
                unique_permission_ids,
            )

        # Always reload the user with all required relationships
        # eagerly loaded before accessing roles/permissions.
        admin_user = await self.admin_user_repository.get_by_id(
            admin_user.id
        )

        if admin_user is None:
            raise ValueError(
                "Admin user could not be reloaded after creation"
            )

        return self._to_read(admin_user)

    async def update_admin_user(
        self,
        admin_user_id: int,
        data: AdminUserUpdate,
    ) -> AdminUserRead | None:
        admin_user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if admin_user is None:
            return None

        update_data = data.model_dump(exclude_unset=True)

        if "password" in update_data:
            password = update_data.pop("password")

            if password is not None:
                password_hash = hash_password(password)

                admin_user.password_hash = password_hash

                # Keep the regular ``users`` account credentials in
                # sync so the admin keeps being able to sign in from
                # the normal WAYN login screen.
                user_result = await self.session.execute(
                    select(User).where(
                        User.email == admin_user.email
                    )
                )
                user = user_result.scalar_one_or_none()

                if user is not None:
                    user.password_hash = password_hash
                    self.session.add(user)

        for field, value in update_data.items():
            setattr(admin_user, field, value)

        admin_user = await self.admin_user_repository.update_admin_user(
            admin_user
        )

        # Reload after commit/refresh so relationships remain eagerly
        # loaded before _to_read() accesses them.
        admin_user = await self.admin_user_repository.get_by_id(
            admin_user.id
        )

        if admin_user is None:
            return None

        return self._to_read(admin_user)

    async def activate_admin_user(
        self,
        admin_user_id: int,
    ) -> AdminUserRead | None:
        admin_user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if admin_user is None:
            return None

        admin_user.is_active = True

        admin_user = await self.admin_user_repository.update_admin_user(
            admin_user
        )

        # Reload relationships after commit.
        admin_user = await self.admin_user_repository.get_by_id(
            admin_user.id
        )

        if admin_user is None:
            return None

        return self._to_read(admin_user)

    async def deactivate_admin_user(
        self,
        admin_user_id: int,
    ) -> AdminUserRead:
        admin_user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if admin_user is None:
            raise ValueError("Admin user not found")

        if any(
            role.is_active and role.name == "super_admin"
            for role in admin_user.roles
        ):
            raise ValueError("Super Admin cannot be deactivated")

        admin_user.is_active = False

        admin_user = await self.admin_user_repository.update_admin_user(
            admin_user
        )

        # Reload relationships after commit.
        admin_user = await self.admin_user_repository.get_by_id(
            admin_user.id
        )

        if admin_user is None:
            raise ValueError("Admin user not found after update")

        return self._to_read(admin_user)

    async def delete_admin_user(
        self,
        admin_user_id: int,
    ) -> None:
        """Delete the AdminUser (and its associations) only.

        The regular ``users`` account that shares the same email is
        deliberately left untouched so the person keeps their normal
        WAYN account.

        Raises:
            ValueError: If the admin does not exist or is a Super Admin.
        """
        admin_user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if admin_user is None:
            raise ValueError("Admin user not found")

        if any(
            role.is_active and role.name == "super_admin"
            for role in admin_user.roles
        ):
            raise ValueError("Super Admin cannot be deleted")

        await self.admin_user_repository.delete_admin_user(
            admin_user_id
        )

    async def list_roles_for_user(
        self,
        admin_user_id: int,
    ) -> list[Role]:
        user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if user is None:
            raise ValueError("Admin user not found")

        return await self.admin_user_repository.get_roles_for_user(
            admin_user_id
        )

    async def add_role_to_user(
        self,
        admin_user_id: int,
        role_id: int,
    ) -> list[Role]:
        user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if user is None:
            raise ValueError("Admin user not found")

        role = await self.role_repository.get_role(role_id)

        if role is None:
            raise ValueError("Role not found")

        await self.admin_user_repository.add_role_to_user(
            admin_user_id,
            role_id,
        )

        return await self.admin_user_repository.get_roles_for_user(
            admin_user_id
        )

    async def remove_role_from_user(
        self,
        admin_user_id: int,
        role_id: int,
    ) -> list[Role]:
        user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if user is None:
            raise ValueError("Admin user not found")

        role = await self.role_repository.get_role(role_id)

        # Removing a role that does not exist is intentionally
        # idempotent. Return the user's current roles without
        # making any database changes.
        if role is None:
            return await self.admin_user_repository.get_roles_for_user(
                admin_user_id
            )

        await self.admin_user_repository.remove_role_from_user(
            admin_user_id,
            role_id,
        )

        return await self.admin_user_repository.get_roles_for_user(
            admin_user_id
        )

    async def replace_user_roles(
        self,
        admin_user_id: int,
        role_ids: list[int],
    ) -> list[Role]:
        user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if user is None:
            raise ValueError("Admin user not found")

        unique_role_ids = list(dict.fromkeys(role_ids))

        for role_id in unique_role_ids:
            role = await self.role_repository.get_role(role_id)

            if role is None:
                raise ValueError(
                    f"Role {role_id} not found"
                )

        await self.admin_user_repository.replace_user_roles(
            admin_user_id,
            unique_role_ids,
        )

        return await self.admin_user_repository.get_roles_for_user(
            admin_user_id
        )

    async def get_resolved_permissions(
        self,
        admin_user_id: int,
    ) -> list[Permission]:
        user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if user is None:
            raise ValueError("Admin user not found")

        resolved: dict[int, Permission] = {}

        for role in user.roles:
            if not role.is_active:
                continue

            for permission in role.permissions:
                resolved[permission.id] = permission

        for permission in user.direct_permissions:
            resolved[permission.id] = permission

        return sorted(
            resolved.values(),
            key=lambda permission: permission.name,
        )