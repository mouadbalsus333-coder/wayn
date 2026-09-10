from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field

from app.models.place_social import PlaceSocialType


class PlaceSocialCreate(BaseModel):
    social_type: PlaceSocialType

    # WhatsApp stores a phone number; every other type stores an http(s) URL.
    # Format validation (URL vs number) happens in PlaceSocialService so the
    # validation has access to the chosen social_type.
    value: str = Field(min_length=1, max_length=1024)


class PlaceSocialRead(BaseModel):
    id: str
    place_id: str
    social_type: PlaceSocialType
    value: str
    created_at: datetime

    model_config = {
        "from_attributes": True,
    }