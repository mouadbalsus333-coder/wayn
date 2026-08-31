"""Pydantic schemas for WAYN Community."""

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class CommunityPostCreate(BaseModel):
    place_id: UUID
    text: str | None = Field(default=None, max_length=5000)
    image_url: str | None = Field(default=None, max_length=1024)
    rating: Decimal | None = Field(default=None)

    @model_validator(mode="after")
    def validate_content(self):
        if not self.text and not self.image_url:
            raise ValueError("Post must contain text or image")
        return self

    @model_validator(mode="after")
    def validate_rating(self):
        if self.rating is not None:
            if self.rating < Decimal("1.0") or self.rating > Decimal("5.0"):
                raise ValueError("Rating must be between 1.0 and 5.0")
            self.rating = round(self.rating, 1)
        return self


class CommunityPostUpdate(BaseModel):
    text: str | None = Field(default=None, max_length=5000)
    image_url: str | None = Field(default=None, max_length=1024)
    rating: Decimal | None = None

    @model_validator(mode="after")
    def validate_rating(self):
        if self.rating is not None:
            if self.rating < Decimal("1.0") or self.rating > Decimal("5.0"):
                raise ValueError("Rating must be between 1.0 and 5.0")
            self.rating = round(self.rating, 1)
        return self


class CommunityPostRead(BaseModel):
    id: UUID
    user_id: UUID
    place_id: UUID
    text: str | None
    image_url: str | None
    rating: Decimal | None
    is_visible: bool
    created_at: datetime
    updated_at: datetime

    author_name: str | None = None
    author_username: str | None = None
    author_avatar: str | None = None
    place_name: str | None = None

    likes_count: int = 0
    saves_count: int = 0
    comments_count: int = 0

    is_liked: bool = False
    is_saved: bool = False

    model_config = {
        "from_attributes": True,
    }


class CommunityCommentCreate(BaseModel):
    text: str = Field(
        min_length=1,
        max_length=2000,
    )


class CommunityCommentRead(BaseModel):
    id: UUID
    post_id: UUID
    user_id: UUID
    text: str
    is_visible: bool
    created_at: datetime
    updated_at: datetime

    author_name: str | None = None
    author_username: str | None = None
    author_avatar: str | None = None

    model_config = {
        "from_attributes": True,
    }