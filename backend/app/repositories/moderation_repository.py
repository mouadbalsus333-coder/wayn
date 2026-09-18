"""Repository for moderation data: appeals, reports and the admin log."""

from datetime import datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin_action_log import (
    AdminActionEntity,
    AdminActionLog,
    AdminActionType,
)
from app.models.community import CommunityPost
from app.models.place import Place
from app.models.post_appeal import AppealStatus, PostAppeal
from app.models.post_report import PostReport, ReportStatus
from app.models.user import User


class ModerationRepository:
    """Database access for post appeals, post reports and audit logs.

    Community post helpers (fetching/updating/deleting rows, counters and
    batch feed data) stay in ``CommunityRepository`` and are reused by
    ``ModerationService`` instead of being duplicated here.
    """

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # ============================================================
    # Appeals
    # ============================================================

    async def create_appeal(
        self,
        appeal: PostAppeal,
    ) -> PostAppeal:
        self.session.add(appeal)
        await self.session.commit()
        await self.session.refresh(appeal)
        return appeal

    async def update_appeal(
        self,
        appeal: PostAppeal,
    ) -> PostAppeal:
        await self.session.commit()
        await self.session.refresh(appeal)
        return appeal

    async def get_appeal(
        self,
        appeal_id: UUID | str,
    ) -> PostAppeal | None:
        result = await self.session.execute(
            select(PostAppeal).where(PostAppeal.id == appeal_id)
        )
        return result.scalar_one_or_none()

    async def get_appeal_by_post_and_user(
        self,
        post_id: UUID | str,
        user_id: UUID | str,
    ) -> PostAppeal | None:
        result = await self.session.execute(
            select(PostAppeal).where(
                PostAppeal.post_id == post_id,
                PostAppeal.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def list_appeals(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
        status: str | None = None,
        type: str | None = None,
        search: str | None = None,
        created_from: datetime | None = None,
        created_to: datetime | None = None,
    ) -> tuple[list[PostAppeal], int]:
        conditions = self._appeal_conditions(
            status=status,
            type=type,
            search=search,
            created_from=created_from,
            created_to=created_to,
        )

        count_result = await self.session.execute(
            select(func.count())
            .select_from(PostAppeal)
            .outerjoin(
                CommunityPost,
                CommunityPost.id == PostAppeal.post_id,
            )
            .where(*conditions)
        )
        total = int(count_result.scalar_one())

        result = await self.session.execute(
            select(PostAppeal)
            .outerjoin(
                CommunityPost,
                CommunityPost.id == PostAppeal.post_id,
            )
            .where(*conditions)
            .order_by(PostAppeal.created_at.desc())
            .offset(offset)
            .limit(limit)
        )

        return list(result.scalars().all()), total

    async def count_appeals_by_status(self) -> dict[str, int]:
        result = await self.session.execute(
            select(
                PostAppeal.status,
                func.count(PostAppeal.id),
            ).group_by(PostAppeal.status)
        )

        counts = {
            status.value: 0 for status in AppealStatus
        }

        for status, count in result.all():
            key = status.value if hasattr(status, "value") else str(status)
            counts[key] = int(count)

        return counts

    def _appeal_conditions(
        self,
        *,
        status: str | None,
        type: str | None,
        search: str | None,
        created_from: datetime | None,
        created_to: datetime | None,
    ) -> list:
        conditions = []

        if status:
            conditions.append(PostAppeal.status == status)

        if type:
            conditions.append(PostAppeal.type == type)

        if created_from is not None:
            conditions.append(PostAppeal.created_at >= created_from)

        if created_to is not None:
            conditions.append(PostAppeal.created_at <= created_to)

        if search and search.strip():
            term = f"%{search.strip()}%"
            conditions.append(
                PostAppeal.reason.ilike(term)
                | CommunityPost.text.ilike(term)
            )

        return conditions

    # ============================================================
    # Reports
    # ============================================================

    async def create_report(
        self,
        report: PostReport,
    ) -> PostReport:
        self.session.add(report)
        await self.session.commit()
        await self.session.refresh(report)
        return report

    async def update_report(
        self,
        report: PostReport,
    ) -> PostReport:
        await self.session.commit()
        await self.session.refresh(report)
        return report

    async def get_report(
        self,
        report_id: UUID | str,
    ) -> PostReport | None:
        result = await self.session.execute(
            select(PostReport).where(PostReport.id == report_id)
        )
        return result.scalar_one_or_none()

    async def get_report_by_post_and_user(
        self,
        post_id: UUID | str,
        user_id: UUID | str,
    ) -> PostReport | None:
        result = await self.session.execute(
            select(PostReport).where(
                PostReport.post_id == post_id,
                PostReport.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def list_reports(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
        status: str | None = None,
        category: str | None = None,
        search: str | None = None,
        created_from: datetime | None = None,
        created_to: datetime | None = None,
    ) -> tuple[list[PostReport], int]:
        conditions = self._report_conditions(
            status=status,
            category=category,
            search=search,
            created_from=created_from,
            created_to=created_to,
        )

        count_result = await self.session.execute(
            select(func.count())
            .select_from(PostReport)
            .outerjoin(
                CommunityPost,
                CommunityPost.id == PostReport.post_id,
            )
            .where(*conditions)
        )
        total = int(count_result.scalar_one())

        result = await self.session.execute(
            select(PostReport)
            .outerjoin(
                CommunityPost,
                CommunityPost.id == PostReport.post_id,
            )
            .where(*conditions)
            .order_by(PostReport.created_at.desc())
            .offset(offset)
            .limit(limit)
        )

        return list(result.scalars().all()), total

    async def count_reports_by_status(self) -> dict[str, int]:
        result = await self.session.execute(
            select(
                PostReport.status,
                func.count(PostReport.id),
            ).group_by(PostReport.status)
        )

        counts = {
            status.value: 0 for status in ReportStatus
        }

        for status, count in result.all():
            key = status.value if hasattr(status, "value") else str(status)
            counts[key] = int(count)

        return counts

    def _report_conditions(
        self,
        *,
        status: str | None,
        category: str | None,
        search: str | None,
        created_from: datetime | None,
        created_to: datetime | None,
    ) -> list:
        conditions = []

        if status:
            conditions.append(PostReport.status == status)

        if category:
            conditions.append(PostReport.category == category)

        if created_from is not None:
            conditions.append(PostReport.created_at >= created_from)

        if created_to is not None:
            conditions.append(PostReport.created_at <= created_to)

        if search and search.strip():
            term = f"%{search.strip()}%"
            conditions.append(
                PostReport.description.ilike(term)
                | CommunityPost.text.ilike(term)
            )

        return conditions

    async def list_appeals_of_user(
        self,
        *,
        user_id: UUID | str,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[PostAppeal], int]:
        conditions = [PostAppeal.user_id == user_id]

        count = await self.session.execute(
            select(func.count())
            .select_from(PostAppeal)
            .where(*conditions)
        )
        total = int(count.scalar_one())

        result = await self.session.execute(
            select(PostAppeal)
            .where(*conditions)
            .order_by(PostAppeal.created_at.desc())
            .offset(offset)
            .limit(limit)
        )

        return list(result.scalars().all()), total

    async def list_reports_of_user(
        self,
        *,
        user_id: UUID | str,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[PostReport], int]:
        conditions = [PostReport.user_id == user_id]

        count = await self.session.execute(
            select(func.count())
            .select_from(PostReport)
            .where(*conditions)
        )
        total = int(count.scalar_one())

        result = await self.session.execute(
            select(PostReport)
            .where(*conditions)
            .order_by(PostReport.created_at.desc())
            .offset(offset)
            .limit(limit)
        )

        return list(result.scalars().all()), total

    # ============================================================
    # Admin action log
    # ============================================================

    async def add_action_log(
        self,
        log: AdminActionLog,
    ) -> AdminActionLog:
        """Stage an audit row (committed with the caller's transaction)."""

        self.session.add(log)
        await self.session.flush()
        return log

    async def list_action_logs(
        self,
        *,
        entity_type: AdminActionEntity,
        entity_id: UUID | str,
        limit: int = 50,
    ) -> list[AdminActionLog]:
        result = await self.session.execute(
            select(AdminActionLog)
            .where(
                AdminActionLog.entity_type == entity_type,
                AdminActionLog.entity_id == entity_id,
            )
            .order_by(AdminActionLog.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def has_post_moderation_action(
        self,
        post_id: UUID | str,
        actions: list[AdminActionType],
    ) -> bool:
        """True when a moderation decision was logged for this post.

        Used to keep a user from restoring a post that moderation
        removed because of an appeal or a report.
        """

        result = await self.session.execute(
            select(AdminActionLog.id)
            .where(
                AdminActionLog.entity_type == AdminActionEntity.POST,
                AdminActionLog.entity_id == post_id,
                AdminActionLog.action.in_(actions),
            )
            .limit(1)
        )

        return result.scalar_one_or_none() is not None

    # ============================================================
    # Batch lookups (admin lists / details)
    # ============================================================

    async def get_users_map(
        self,
        user_ids: list[UUID],
    ) -> dict[UUID, User]:
        ids = {user_id for user_id in user_ids if user_id is not None}

        if not ids:
            return {}

        result = await self.session.execute(
            select(User).where(User.id.in_(ids))
        )

        return {user.id: user for user in result.scalars().all()}

    async def get_posts_map(
        self,
        post_ids: list[UUID],
    ) -> dict[UUID, CommunityPost]:
        ids = {post_id for post_id in post_ids if post_id is not None}

        if not ids:
            return {}

        result = await self.session.execute(
            select(CommunityPost).where(CommunityPost.id.in_(ids))
        )

        return {post.id: post for post in result.scalars().all()}

    async def get_places_map(
        self,
        place_ids: list[UUID],
    ) -> dict[UUID, Place]:
        ids = {place_id for place_id in place_ids if place_id is not None}

        if not ids:
            return {}

        result = await self.session.execute(
            select(Place).where(Place.id.in_(ids))
        )

        return {place.id: place for place in result.scalars().all()}

    async def get_admins_map(
        self,
        admin_ids: list[UUID],
    ) -> dict[UUID, str | None]:
        """Map admin ids to their email (for the audit trail)."""

        ids = {admin_id for admin_id in admin_ids if admin_id is not None}

        if not ids:
            return {}

        from app.models.admin_user import AdminUser

        result = await self.session.execute(
            select(AdminUser.id, AdminUser.email).where(
                AdminUser.id.in_(ids)
            )
        )

        return {row[0]: row[1] for row in result.all()}