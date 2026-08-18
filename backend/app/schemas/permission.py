from pydantic import BaseModel, Field


class PermissionCreate(BaseModel):
    name: str = Field(
        min_length=1,
        max_length=150,
    )
    description: str | None = Field(
        default=None,
        max_length=255,
    )


class PermissionUpdate(BaseModel):
    name: str | None = Field(
        default=None,
        min_length=1,
        max_length=150,
    )
    description: str | None = Field(
        default=None,
        max_length=255,
    )


class PermissionRead(BaseModel):
    id: int
    name: str
    description: str | None
    created_at: object

    model_config = {
        "from_attributes": True,
    }
