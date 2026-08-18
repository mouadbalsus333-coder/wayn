"""Store API schemas."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.store_item import (
    StoreItemCurrency,
    StoreItemType,
)


# ============================================================
# Store Category
# ============================================================

class StoreCategoryCreate(BaseModel):
    name_ar: str = Field(
        min_length=1,
        max_length=100,
    )
    name_en: str = Field(
        min_length=1,
        max_length=100,
    )
    description_ar: str | None = None
    description_en: str | None = None
    icon_url: str | None = Field(
        default=None,
        max_length=500,
    )
    image_url: str | None = Field(
        default=None,
        max_length=500,
    )
    sort_order: int = 0
    is_active: bool = True


class StoreCategoryUpdate(BaseModel):
    name_ar: str | None = Field(
        default=None,
        min_length=1,
        max_length=100,
    )
    name_en: str | None = Field(
        default=None,
        min_length=1,
        max_length=100,
    )
    description_ar: str | None = None
    description_en: str | None = None
    icon_url: str | None = Field(
        default=None,
        max_length=500,
    )
    image_url: str | None = Field(
        default=None,
        max_length=500,
    )
    sort_order: int | None = None
    is_active: bool | None = None


class StoreCategoryRead(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: UUID
    name_ar: str
    name_en: str
    description_ar: str | None
    description_en: str | None
    icon_url: str | None
    image_url: str | None
    sort_order: int
    is_active: bool
    created_at: datetime
    updated_at: datetime


# ============================================================
# Store Item
# ============================================================

class StoreItemCreate(BaseModel):
    category_id: UUID

    name_ar: str = Field(
        min_length=1,
        max_length=150,
    )
    name_en: str = Field(
        min_length=1,
        max_length=150,
    )

    description_ar: str | None = None
    description_en: str | None = None

    item_type: StoreItemType
    currency: StoreItemCurrency

    price: int = Field(
        ge=0,
    )

    image_url: str | None = Field(
        default=None,
        max_length=500,
    )

    asset_id: str | None = Field(
        default=None,
        max_length=150,
    )

    duration_days: int | None = Field(
        default=None,
        gt=0,
    )

    stock: int | None = Field(
        default=None,
        ge=0,
    )

    sort_order: int = 0
    is_active: bool = True


class StoreItemUpdate(BaseModel):
    category_id: UUID | None = None

    name_ar: str | None = Field(
        default=None,
        min_length=1,
        max_length=150,
    )
    name_en: str | None = Field(
        default=None,
        min_length=1,
        max_length=150,
    )

    description_ar: str | None = None
    description_en: str | None = None

    item_type: StoreItemType | None = None
    currency: StoreItemCurrency | None = None

    price: int | None = Field(
        default=None,
        ge=0,
    )

    image_url: str | None = Field(
        default=None,
        max_length=500,
    )

    asset_id: str | None = Field(
        default=None,
        max_length=150,
    )

    duration_days: int | None = Field(
        default=None,
        gt=0,
    )

    stock: int | None = Field(
        default=None,
        ge=0,
    )

    sort_order: int | None = None
    is_active: bool | None = None


class StoreItemRead(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: UUID
    category_id: UUID

    name_ar: str
    name_en: str

    description_ar: str | None
    description_en: str | None

    item_type: StoreItemType
    currency: StoreItemCurrency

    price: int

    image_url: str | None
    asset_id: str | None
    duration_days: int | None
    stock: int | None

    sort_order: int
    is_active: bool

    created_at: datetime
    updated_at: datetime


# ============================================================
# Store Banner
# ============================================================

class StoreBannerCreate(BaseModel):
    title_ar: str | None = Field(
        default=None,
        max_length=200,
    )
    title_en: str | None = Field(
        default=None,
        max_length=200,
    )

    image_url: str = Field(
        min_length=1,
        max_length=500,
    )

    target_url: str | None = Field(
        default=None,
        max_length=500,
    )

    sort_order: int = 0
    is_active: bool = True

    starts_at: datetime | None = None
    ends_at: datetime | None = None


class StoreBannerUpdate(BaseModel):
    title_ar: str | None = Field(
        default=None,
        max_length=200,
    )
    title_en: str | None = Field(
        default=None,
        max_length=200,
    )

    image_url: str | None = Field(
        default=None,
        min_length=1,
        max_length=500,
    )

    target_url: str | None = Field(
        default=None,
        max_length=500,
    )

    sort_order: int | None = None
    is_active: bool | None = None

    starts_at: datetime | None = None
    ends_at: datetime | None = None


class StoreBannerRead(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: UUID

    title_ar: str | None
    title_en: str | None

    image_url: str
    target_url: str | None

    sort_order: int
    is_active: bool

    starts_at: datetime | None
    ends_at: datetime | None

    created_at: datetime
    updated_at: datetime