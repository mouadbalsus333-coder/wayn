from app.api.dependencies.admin_auth import get_admin_permissions
from app.core.security import hash_password
from app.models.admin_user import AdminUser
from app.models.permission import Permission
from app.models.role import Role
from app.repositories.admin_user_repository import AdminUserRepository
from app.repositories.role_repository import RoleRepository
from app.schemas.admin_user import (
    AdminUserCreate,
    AdminUserRead,
    AdminUserUpdate,
)


class AdminUserService:
    def __init__(
        self,
        admin_user_repository: AdminUserRepository,
        role_repository: RoleRepository,
    ):
        self.admin_user_repository = admin_user_repository
        self.role_repository = role_repository

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

        admin_user = AdminUser(
            email=normalized_email,
            password_hash=hash_password(data.password),
            full_name=data.full_name,
            is_active=data.is_active,
        )

        admin_user = await self.admin_user_repository.create_admin_user(
            admin_user
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
                admin_user.password_hash = hash_password(password)

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
    ) -> AdminUserRead | None:
        admin_user = await self.admin_user_repository.get_by_id(
            admin_user_id
        )

        if admin_user is None:
            return None

        admin_user.is_active = False

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