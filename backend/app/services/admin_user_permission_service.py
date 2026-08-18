from app.models.permission import Permission
from app.repositories.admin_user_permission_repository import (
    AdminUserPermissionRepository,
)


class AdminUserPermissionService:
    def __init__(
        self,
        repository: AdminUserPermissionRepository,
    ):
        self.repository = repository

    async def get_user_permissions(
        self,
        admin_user_id: int,
    ) -> list[Permission]:
        admin_user = await self.repository.get_admin_user(
            admin_user_id
        )

        if admin_user is None:
            raise ValueError("Admin user not found")

        return await self.repository.list_permissions_for_user(
            admin_user_id
        )

    async def replace_user_permissions(
        self,
        admin_user_id: int,
        permission_ids: list[int],
    ) -> list[Permission]:

        admin_user = await self.repository.get_admin_user(
            admin_user_id
        )

        if admin_user is None:
            raise ValueError("Admin user not found")

        unique_permission_ids = list(
            dict.fromkeys(permission_ids)
        )

        for permission_id in unique_permission_ids:
            permission = await self.repository.get_permission(
                permission_id
            )

            if permission is None:
                raise ValueError(
                    f"Permission {permission_id} not found"
                )

        await self.repository.replace_user_permissions(
            admin_user_id=admin_user_id,
            permission_ids=unique_permission_ids,
        )

        return await self.repository.list_permissions_for_user(
            admin_user_id
        )

    async def add_permission(
        self,
        admin_user_id: int,
        permission_id: int,
    ) -> list[Permission]:

        admin_user = await self.repository.get_admin_user(
            admin_user_id
        )

        if admin_user is None:
            raise ValueError("Admin user not found")

        permission = await self.repository.get_permission(
            permission_id
        )

        if permission is None:
            raise ValueError("Permission not found")

        await self.repository.add_permission_to_user(
            admin_user_id=admin_user_id,
            permission_id=permission_id,
        )

        return await self.repository.list_permissions_for_user(
            admin_user_id
        )

    async def remove_permission(
        self,
        admin_user_id: int,
        permission_id: int,
    ) -> list[Permission]:

        admin_user = await self.repository.get_admin_user(
            admin_user_id
        )

        if admin_user is None:
            raise ValueError("Admin user not found")

        permission = await self.repository.get_permission(
            permission_id
        )

        if permission is None:
            raise ValueError("Permission not found")

        await self.repository.remove_permission_from_user(
            admin_user_id=admin_user_id,
            permission_id=permission_id,
        )

        return await self.repository.list_permissions_for_user(
            admin_user_id
        )