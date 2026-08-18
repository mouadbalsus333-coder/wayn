from app.models.permission import Permission
from app.repositories.permission_repository import PermissionRepository
from app.schemas.permission import (
    PermissionCreate,
    PermissionUpdate,
)


class PermissionService:
    def __init__(
        self,
        repository: PermissionRepository,
    ):
        self.repository = repository

    async def get_permissions(self) -> list[Permission]:
        return await self.repository.list_permissions()

    async def get_permission(
        self,
        permission_id: int,
    ) -> Permission | None:
        return await self.repository.get_permission(
            permission_id
        )

    async def create_permission(
        self,
        data: PermissionCreate,
    ) -> Permission:
        existing = await self.repository.get_by_name(
            data.name
        )

        if existing is not None:
            raise ValueError(
                "Permission already exists"
            )

        permission = Permission(
            name=data.name,
            description=data.description,
        )

        return await self.repository.create_permission(
            permission
        )

    async def update_permission(
        self,
        permission: Permission,
        data: PermissionUpdate,
    ) -> Permission:
        update_data = data.model_dump(
            exclude_unset=True
        )

        if "name" in update_data:
            existing = await self.repository.get_by_name(
                update_data["name"]
            )

            if (
                existing is not None
                and existing.id != permission.id
            ):
                raise ValueError(
                    "Permission already exists"
                )

        for field, value in update_data.items():
            setattr(
                permission,
                field,
                value,
            )

        return await self.repository.update_permission(
            permission
        )

    async def delete_permission(
        self,
        permission: Permission,
    ) -> None:
        await self.repository.delete_permission(
            permission
        )
