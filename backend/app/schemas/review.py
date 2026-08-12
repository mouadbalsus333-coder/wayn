"""Pydantic schemas for place reviews."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, field_validator


class ReviewCreate(BaseModel):
    rating: Decimal = Field(
        description="Rating between 1.0 and 5.0 (one decimal place)",
    )
    comment: str | None = None
    images: list[str] = Field(default_factory=list)

    @field_validator("rating")
    @classmethod
    def validate_rating(cls, v: Decimal) -> Decimal:
        if v < Decimal("1.0") or v > Decimal("5.0"):
            raise ValueError("Rating must be between 1.0 and 5.0")
        return round(v, 1)


class ReviewUpdate(BaseModel):
    rating: Decimal | None = None
    comment: str | None = None
    images: list[str] | None = None
    is_visible: bool | None = None

    @field_validator("rating")
    @classmethod
    def validate_rating(cls, v: Decimal | None) -> Decimal | None:
        if v is not None:
            if v < Decimal("1.0") or v > Decimal("5.0"):
                raise ValueError("Rating must be between 1.0 and 5.0")
            return round(v, 1)
        return v


class ReviewRead(BaseModel):
    id: str
    place_id: str
    user_id: str
    rating: float  # serialized as float for JSON / Flutter
    comment: str | None
    images: list[str]
    is_visible: bool
    created_at: datetime
    updated_at: datetime

    model_config = {
        "from_attributes": True,
    }
