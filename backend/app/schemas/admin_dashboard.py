from pydantic import BaseModel


class AdminDashboardSummary(BaseModel):
    total_users: int | None = None
    active_users: int | None = None
    total_places: int | None = None
    pending_places: int | None = None
    pending_contributions: int | None = None
    visible_community_posts: int | None = None
    visible_reviews: int | None = None
    wallet_recharge_operations: int | None = None