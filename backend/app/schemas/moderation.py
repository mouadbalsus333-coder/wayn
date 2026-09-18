"""Pydantic schemas for post moderation.

Covers the two independent user-facing flows and their admin management:

- rating appeals (الطعن في التقييم)  → ``Appeal*``
- post reports (الإبلاغ عن منشور)    → ``Report*``
- internal admin audit trail         → ``AdminActionLogRead``
"""

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


# ============================================================
# Allowed values (mirror the model enums)
# ============================================================

APPEAL_TYPES = {"INCORRECT_RATING", "MISLEADING_RATING", "OTHER"}

APPEAL_STATUSES = {
    "PENDING",
    "UNDER_REVIEW",
    "RESOLVED",
    "REJECTED",
    "CANCELLED",
}

REPORT_CATEGORIES = {
    "ABUSE",
    "INAPPROPRIATE_CONTENT",
    "SPAM",
    "FALSE_INFO",
    "OTHER",
}

REPORT_STATUSES = APPEAL_STATUSES

POST_ACTIONS = {"DELETE_POST", "HIDE_POST", "LEAVE_AS_IS"}


# ============================================================
# Shared: post preview shown to admins
# ============================================================


class ModerationPostPreview(BaseModel):
    """Read-only snapshot of the post under review."""

    id: UUID
    user_id: UUID
    place_id: UUID

    text: str | None = None
    image_url: str | None = None
    rating: Decimal | None = None

    is_visible: bool = True
    visibility_state: str | None = None
    deleted_at: datetime | None = None
    hidden_at: datetime | None = None

    created_at: datetime
    updated_at: datetime | None = None

    author_name: str | None = None
    author_username: str | None = None
    author_avatar: str | None = None

    place_name: str | None = None
    place_city: str | None = None

    likes_count: int = 0
    saves_count: int = 0
    comments_count: int = 0

    model_config = {
        "from_attributes": True,
    }


class ModerationStats(BaseModel):
    """Queue counters used by the admin dashboards."""

    total: int = 0
    pending: int = 0
    under_review: int = 0
    resolved: int = 0
    rejected: int = 0
    cancelled: int = 0


class PostActionUpdate(BaseModel):
    """Admin decision applied to the post itself.

    Kept separate from the appeal/report status on purpose: changing a
    status never hides or deletes a post on its own.
    """

    action: str
    notes: str | None = Field(default=None, max_length=5000)

    @model_validator(mode="after")
    def validate_action(self):
        if self.action not in POST_ACTIONS:
            raise ValueError(
                f"Invalid action. Must be one of: {POST_ACTIONS}"
            )
        return self


class AdminActionLogRead(BaseModel):
    id: UUID
    admin_user_id: int | None = None
    admin_email: str | None = None

    entity_type: str
    entity_id: UUID
    action: str

    notes: str | None = None
    created_at: datetime

    model_config = {
        "from_attributes": True,
    }


# ============================================================
# Appeals (الطعن في التقييم)
# ============================================================


class AppealCreate(BaseModel):
    type: str = "INCORRECT_RATING"
    reason: str = Field(
        min_length=10,
        max_length=5000,
        description="Detailed explanation of the appeal (required)",
    )

    @model_validator(mode="after")
    def validate_type(self):
        if self.type not in APPEAL_TYPES:
            raise ValueError(
                f"Invalid appeal type. Must be one of: {APPEAL_TYPES}"
            )

        reason = (self.reason or "").strip()

        if len(reason) < 10:
            raise ValueError(
                "Appeal reason must be at least 10 characters"
            )

        self.reason = reason

        return self


class AppealRead(BaseModel):
    """Appeal as seen by the user who filed it."""

    id: UUID
    post_id: UUID
    user_id: UUID

    type: str
    reason: str
    status: str

    action_taken: str | None = None
    reviewed_at: datetime | None = None

    created_at: datetime
    updated_at: datetime

    model_config = {
        "from_attributes": True,
    }


class AppealAdminRead(BaseModel):
    """Full appeal record for the admin web."""

    id: UUID
    post_id: UUID
    user_id: UUID

    type: str
    reason: str
    status: str

    admin_notes: str | None = None
    action_taken: str | None = None

    reviewed_by: int | None = None
    reviewed_by_email: str | None = None
    reviewed_at: datetime | None = None

    created_at: datetime
    updated_at: datetime

    # Complainant
    complainant_name: str | None = None
    complainant_username: str | None = None
    complainant_avatar: str | None = None
    complainant_email: str | None = None

    # Post owner
    post_owner_id: UUID | None = None
    post_owner_name: str | None = None
    post_owner_username: str | None = None
    post_owner_avatar: str | None = None

    # Post content
    post: ModerationPostPreview | None = None

    # Admin trail
    actions: list[AdminActionLogRead] = []

    model_config = {
        "from_attributes": True,
    }


class AppealAdminListItem(BaseModel):
    """Compact appeal row for the admin list."""

    id: UUID
    post_id: UUID
    user_id: UUID

    type: str
    status: str
    reason: str

    action_taken: str | None = None

    created_at: datetime
    updated_at: datetime
    reviewed_at: datetime | None = None

    complainant_name: str | None = None
    complainant_username: str | None = None

    post_owner_name: str | None = None
    post_owner_username: str | None = None

    model_config = {
        "from_attributes": True,
    }


class AppealStatusUpdate(BaseModel):
    status: str
    admin_notes: str | None = Field(default=None, max_length=5000)

    @model_validator(mode="after")
    def validate_status(self):
        if self.status not in APPEAL_STATUSES:
            raise ValueError(
                f"Invalid status. Must be one of: {APPEAL_STATUSES}"
            )

        if self.admin_notes is not None:
            self.admin_notes = self.admin_notes.strip() or None

        return self


# ============================================================
# Reports (الإبلاغ عن منشور)
# ============================================================


class ReportCreate(BaseModel):
    category: str = "OTHER"
    description: str = Field(
        min_length=10,
        max_length=5000,
        description="What is wrong with this post (required)",
    )

    @model_validator(mode="after")
    def validate_category(self):
        if self.category not in REPORT_CATEGORIES:
            raise ValueError(
                "Invalid report category. Must be one of: "
                f"{REPORT_CATEGORIES}"
            )

        description = (self.description or "").strip()

        if len(description) < 10:
            raise ValueError(
                "Report description must be at least 10 characters"
            )

        self.description = description

        return self


class ReportRead(BaseModel):
    """Report as seen by the user who filed it."""

    id: UUID
    post_id: UUID
    user_id: UUID

    category: str
    description: str
    status: str

    action_taken: str | None = None
    reviewed_at: datetime | None = None

    created_at: datetime
    updated_at: datetime

    model_config = {
        "from_attributes": True,
    }


class ReportAdminListItem(BaseModel):
    """Compact report row for the admin list."""

    id: UUID
    post_id: UUID
    user_id: UUID

    category: str
    status: str
    description: str

    action_taken: str | None = None

    created_at: datetime
    updated_at: datetime
    reviewed_at: datetime | None = None

    reporter_name: str | None = None
    reporter_username: str | None = None

    post_owner_name: str | None = None
    post_owner_username: str | None = None

    model_config = {
        "from_attributes": True,
    }


class ReportAdminRead(BaseModel):
    """Full report record for the admin web."""

    id: UUID
    post_id: UUID
    user_id: UUID

    category: str
    description: str
    status: str

    admin_notes: str | None = None
    action_taken: str | None = None

    reviewed_by: int | None = None
    reviewed_by_email: str | None = None
    reviewed_at: datetime | None = None

    created_at: datetime
    updated_at: datetime

    # Reporter
    reporter_name: str | None = None
    reporter_username: str | None = None
    reporter_avatar: str | None = None
    reporter_email: str | None = None

    # Post owner
    post_owner_id: UUID | None = None
    post_owner_name: str | None = None
    post_owner_username: str | None = None
    post_owner_avatar: str | None = None

    # Post content
    post: ModerationPostPreview | None = None

    # Admin trail
    actions: list[AdminActionLogRead] = []

    model_config = {
        "from_attributes": True,
    }


class ReportStatusUpdate(BaseModel):
    status: str
    admin_notes: str | None = Field(default=None, max_length=5000)

    @model_validator(mode="after")
    def validate_status(self):
        if self.status not in REPORT_STATUSES:
            raise ValueError(
                f"Invalid status. Must be one of: {REPORT_STATUSES}"
            )

        if self.admin_notes is not None:
            self.admin_notes = self.admin_notes.strip() or None

        return self