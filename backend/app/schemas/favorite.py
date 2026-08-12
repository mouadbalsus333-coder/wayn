"""Pydantic schemas for user favorites."""

from datetime import datetime

from pydantic import BaseModel


class FavoriteCreate(BaseModel):
    """Body for adding a place to favourites (place_id comes from path param)."""
    pass


class FavoriteRead(BaseModel):
    id: str
    user_id: str
    place_id: str
    created_at: datetime

    model_config = {
        "from_attributes": True,
    }
