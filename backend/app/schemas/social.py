"""Pydantic schemas for public user profiles, follows, and notifications."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class PublicUserRead(BaseModel):
    id: UUID
    username: str
    full_name: str
    avatar_id: str | None
    bio: str | None
    points: int = 0
    followers_count: int = 0
    following_count: int = 0
    ratings_count: int = 0
    is_following: bool = False
    is_owner: bool = False

    model_config = {
        "from_attributes": True,
    }


class FollowResult(BaseModel):
    user_id: UUID
    is_following: bool
    followers_count: int


class NotificationRead(BaseModel):
    id: UUID
    type: str
    text: str
    actor_name: str | None
    actor_avatar: str | None
    is_read: bool
    created_at: datetime

    model_config = {
        "from_attributes": True,
    }


class UnreadCountRead(BaseModel):
    count: int
