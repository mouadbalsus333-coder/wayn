from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import get_admin_permissions
from app.models.community import CommunityPost
from app.models.place import Place, VerificationStatus
from app.models.place_contribution import (
    PlaceContribution,
    PlaceContributionStatus,
)
from app.models.review import PlaceReview
from app.models.user import AccountStatus, User
from app.models.wallet_admin_recharge import WalletAdminRecharge
from app.schemas.admin_dashboard import AdminDashboardSummary


class AdminDashboardService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def _count(self, model, *conditions) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(model).where(*conditions)
        )
        return int(result.scalar_one())

    async def get_summary(self, admin_user) -> AdminDashboardSummary:
        permissions = get_admin_permissions(admin_user)
        summary = AdminDashboardSummary()

        if "users.read" in permissions:
            summary.total_users = await self._count(User)
            summary.active_users = await self._count(
                User,
                User.is_active.is_(True),
                User.account_status == AccountStatus.ACTIVE,
            )

        if "places.read" in permissions:
            summary.total_places = await self._count(
                Place,
                Place.deleted_at.is_(None),
            )
            summary.pending_places = await self._count(
                Place,
                Place.deleted_at.is_(None),
                Place.verification_status == VerificationStatus.PENDING,
            )

        if "contributions.read" in permissions:
            summary.pending_contributions = await self._count(
                PlaceContribution,
                PlaceContribution.status == PlaceContributionStatus.PENDING,
            )

        if "community.read" in permissions:
            summary.visible_community_posts = await self._count(
                CommunityPost,
                CommunityPost.is_visible.is_(True),
            )

        if "reviews.read" in permissions:
            summary.visible_reviews = await self._count(
                PlaceReview,
                PlaceReview.is_visible.is_(True),
            )

        if "wallet.read" in permissions:
            summary.wallet_recharge_operations = await self._count(
                WalletAdminRecharge,
            )

        return summary