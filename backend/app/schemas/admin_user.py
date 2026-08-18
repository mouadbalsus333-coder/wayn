from pydantic import BaseModel, EmailStr, Field


class AdminUserCreate(BaseModel):
    email: EmailStr
    password: str = Field(
        min_length=8,
        max_length=128,
    )
    full_name: str = Field(
        min_length=1,
        max_length=255,
    )
    is_active: bool = True
    role_ids: list[int] | None = None


class AdminUserUpdate(BaseModel):
    full_name: str | None = Field(
        default=None,
        min_length=1,
        max_length=255,
    )
    password: str | None = Field(
        default=None,
        min_length=8,
        max_length=128,
    )
    is_active: bool | None = None


class AdminUserRead(BaseModel):
    id: int
    email: EmailStr
    full_name: str
    is_active: bool
    roles: list[str]
    permissions: list[str]


class AdminUserRoleUpdate(BaseModel):
    role_ids: list[int] = Field(
        default_factory=list,
    )
