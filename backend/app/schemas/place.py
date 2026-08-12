from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class PlaceCreate(BaseModel):
    category_id: str | None = None
    owner_user_id: str | None = None

    name: str = Field(
        min_length=1,
        max_length=255,
    )

    city: str = Field(
        min_length=1,
        max_length=255,
    )

    category_name: str = Field(
        min_length=1,
        max_length=255,
    )

    image_url: str = Field(
        min_length=1,
        max_length=1024,
    )

    rating: float = 0.0
    is_open: bool = False
    is_active: bool = True

    description: str | None = None
    address: str | None = None
    phone: str | None = None
    website: str | None = None

    latitude: float | None = None
    longitude: float | None = None

    images: list[str] = Field(
        default_factory=list
    )

    services: list[str] = Field(
        default_factory=list
    )

    opening_time: str | None = None
    closing_time: str | None = None
    working_hours_json: dict[str, Any] | None = None


class PlaceUpdate(BaseModel):
    category_id: str | None = None
    owner_user_id: str | None = None
    verification_status: str | None = None

    name: str | None = Field(
        default=None,
        min_length=1,
        max_length=255,
    )

    city: str | None = Field(
        default=None,
        min_length=1,
        max_length=255,
    )

    category_name: str | None = Field(
        default=None,
        min_length=1,
        max_length=255,
    )

    image_url: str | None = Field(
        default=None,
        min_length=1,
        max_length=1024,
    )

    rating: float | None = None
    is_open: bool | None = None
    is_active: bool | None = None

    description: str | None = None
    address: str | None = None
    phone: str | None = None
    website: str | None = None

    latitude: float | None = None
    longitude: float | None = None

    images: list[str] | None = None
    services: list[str] | None = None

    opening_time: str | None = None
    closing_time: str | None = None
    working_hours_json: dict[str, Any] | None = None


class PlaceRead(BaseModel):
    # Core fields — kept identical to existing Flutter API contract.
    id: str
    category_id: str | None
    name: str
    city: str
    category_name: str
    image_url: str
    rating: float
    is_open: bool
    is_active: bool
    description: str | None
    address: str | None
    phone: str | None
    website: str | None
    latitude: float | None
    longitude: float | None
    images: list[str]
    services: list[str]
    opening_time: str | None
    closing_time: str | None
    reviews_count: int
    visits_count: int

    # New optional fields — Flutter will ignore unknown fields gracefully.
    owner_user_id: str | None = None
    verification_status: str | None = None
    working_hours_json: dict[str, Any] | None = None
    deleted_at: datetime | None = None

    model_config = {
        "from_attributes": True,
    }