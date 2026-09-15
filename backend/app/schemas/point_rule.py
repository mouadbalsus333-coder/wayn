"""Schemas for point rules (tasks)."""

from datetime import datetime

from pydantic import BaseModel, Field

from app.models.point_rule import PointRule


class PointRuleRead(BaseModel):
    id: int
    action_key: str
    points: int
    title: str
    description: str | None
    is_active: bool
    requires_approval: bool
    limit_per_user: int | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class PointRuleCreate(BaseModel):
    action_key: str = Field(min_length=1, max_length=100)
    points: int = Field(ge=0)
    title: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=255)
    is_active: bool = True
    requires_approval: bool = True
    limit_per_user: int | None = Field(default=None, ge=1)


class PointRuleUpdate(BaseModel):
    points: int | None = Field(default=None, ge=0)
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=255)
    is_active: bool | None = None
    requires_approval: bool | None = None
    limit_per_user: int | None = Field(default=None, ge=1)


class RewardTaskRead(BaseModel):
    """Task visible to end users (only active rules)."""

    id: int
    key: str
    title: str
    description: str | None
    reward_points: int
    requires_approval: bool

    @classmethod
    def from_rule(cls, rule: PointRule) -> "RewardTaskRead":
        return cls(
            id=rule.id,
            key=rule.action_key,
            title=rule.title,
            description=rule.description,
            reward_points=rule.points,
            requires_approval=rule.requires_approval,
        )
