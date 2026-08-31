"""Schemas for place contributions."""

from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.place_contribution import (
    PlaceContributionStatus,
    PlaceContributionType,
)


# ============================================================
# Create
# ============================================================


class PlaceContributionCreate(BaseModel):
    type: PlaceContributionType

    title: str = Field(
        min_length=1,
        max_length=255,
    )

    description: str | None = None

    payload: dict[str, Any] = Field(
        default_factory=dict,
    )

    place_id: UUID | None = None


# ============================================================
# Read
# ============================================================


class PlaceContributionRead(BaseModel):
    id: UUID

    user_id: UUID

    place_id: UUID | None

    type: PlaceContributionType

    status: PlaceContributionStatus

    title: str

    description: str | None

    payload: dict[str, Any]

    reviewed_by: int | None

    reviewed_at: datetime | None

    rejection_reason: str | None

    points_awarded: int

    created_at: datetime

    updated_at: datetime

    model_config = {
        "from_attributes": True,
    }


# ============================================================
# List response
# ============================================================


class PlaceContributionListResponse(BaseModel):
    items: list[PlaceContributionRead]

    total: int

    offset: int

    limit: int


# ============================================================
# Admin approval
# ============================================================


class PlaceContributionApproveRequest(BaseModel):
    points: int | None = Field(
        default=None,
        ge=0,
    )


# ============================================================
# Admin rejection
# ============================================================


class PlaceContributionRejectRequest(BaseModel):
    rejection_reason: str = Field(
        min_length=1,
        max_length=2000,
    )