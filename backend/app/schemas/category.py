from pydantic import BaseModel, Field


class CategoryCreate(BaseModel):
    name_ar: str = Field(min_length=1, max_length=255)
    name_en: str | None = Field(default=None, max_length=255)
    icon: str | None = Field(default=None, max_length=255)
    sort_order: int = 0
    is_active: bool = True
    parent_id: str | None = None


class CategoryUpdate(BaseModel):
    name_ar: str | None = Field(default=None, min_length=1, max_length=255)
    name_en: str | None = Field(default=None, max_length=255)
    icon: str | None = Field(default=None, max_length=255)
    sort_order: int | None = None
    is_active: bool | None = None
    parent_id: str | None = None


class CategoryRead(BaseModel):
    id: str
    name_ar: str
    name_en: str | None
    icon: str | None
    sort_order: int
    is_active: bool
    parent_id: str | None = None  # new field — Flutter ignores unknown fields

    model_config = {
        "from_attributes": True,
    }