from pydantic import BaseModel


class RoleRead(BaseModel):
    id: int
    name: str
    description: str | None = None
    is_active: bool

    model_config = {
        "from_attributes": True,
    }
