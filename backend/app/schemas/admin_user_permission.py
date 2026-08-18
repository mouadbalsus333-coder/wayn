from pydantic import BaseModel, Field


class AdminUserPermissionRead(BaseModel):
    id: int
    name: str
    description: str | None = None


class AdminUserPermissionUpdate(BaseModel):
    permission_ids: list[int] = Field(
        default_factory=list,
    )