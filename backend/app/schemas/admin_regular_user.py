from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

from app.models.user import AccountStatus


class AdminRegularUserRead(BaseModel):
    id: UUID
    email: str
    full_name: str
    username: str
    phone: str | None
    account_status: AccountStatus
    is_active: bool
    is_verified: bool
    points: int
    created_at: datetime
    last_login_at: datetime | None

    model_config = {"from_attributes": True}


class AdminRegularUserStatusUpdate(BaseModel):
    account_status: AccountStatus | None = None
    is_active: bool | None = None
    status_reason: str | None = None
    suspended_until: datetime | None = None