"""Business logic for post moderation (appeals + reports).

The service owns every moderation rule:
- who may file an appeal/report (own posts cannot be appealed/reported,
  deleted posts cannot be appealed/reported),
- what a valid status transition is,
- what the post decision does to the post,
- the admin audit trail and the user notification.

Routers only translate HTTP <-> service calls.
"""

from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin_action_log import (
    AdminActionEntity,
    AdminActionLog,
    AdminActionType,
)
from app.models.community import CommunityPost, PostVisibilityState
from app.models.post_appeal import (
    AppealPostAction,
    AppealStatus,
    PostAppeal,
)
from app.models.post_report import (
    PostReport,
    ReportPostAction,
    ReportStatus,
)
from app.repositories.community_repository import CommunityRepository
from app.repositories.device_repository import DeviceRepository
from app.repositories.moderation_repository import ModerationRepository
from app.services.fcm_service import fcm_service


# ============================================================
# Status rules
# ============================================================

# Statuses that mean "this appeal/report is being handled".
ACTIVE_STATUSES = {
    AppealStatus.PENDING.value,
    AppealStatus.UNDER_REVIEW.value,
}

CLOSED_STATUSES = {
    AppealStatus.RESOLVED.value,
    AppealStatus.REJECTED.value,
    AppealStatus.CANCELLED.value,
}

# Allowed transitions. A closed record can only be reopened by the
# service when the same user files a new appeal/report.
STATUS_TRANSITIONS = {
    AppealStatus.PENDING.value: {
        AppealStatus.UNDER_REVIEW.value,
        AppealStatus.RESOLVED.value,
        AppealStatus.REJECTED.value,
        AppealStatus.CANCELLED.value,
    },
    AppealStatus.UNDER_REVIEW.value: {
        AppealStatus.RESOLVED.value,
        AppealStatus.REJECTED.value,
        AppealStatus.CANCELLED.value,
    },
    AppealStatus.RESOLVED.value: set(),
    AppealStatus.REJECTED.value: set(),
    AppealStatus.CANCELLED.value: set(),
}


class ModerationError(ValueError):
    """Raised when a moderation rule is violated."""


class ModerationService:
    """Appeals, reports, their admin decisions and notifications."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = ModerationRepository(session)
        self.community_repository = CommunityRepository(session)
        self.device_repository = DeviceRepository(session)

    # ============================================================
    # User side: appeals
    # ============================================================

    async def submit_appeal(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
        type: str,
        reason: str,
    ) -> PostAppeal:
        """File a rating appeal for a post owned by somebody else."""

        self._ensure_post_can_be_moderated(
            post=post,
            user_id=user_id,
            label="appeal",
        )

        reason = (reason or "").strip()

        existing = await self.repository.get_appeal_by_post_and_user(
            post.id,
            user_id,
        )

        if existing is not None:
            if existing.status in ACTIVE_STATUSES:
                raise ModerationError(
                    "Your appeal for this post is already under review"
                )

            # A closed appeal can be re-opened with the new reason.
            existing.type = type
            existing.reason = reason
            existing.status = AppealStatus.PENDING.value
            existing.admin_notes = None
            existing.action_taken = None
            existing.reviewed_by = None
            existing.reviewed_at = None

            return await self.repository.update_appeal(existing)

        appeal = PostAppeal(
            post_id=post.id,
            user_id=user_id,
            type=type,
            reason=reason,
            status=AppealStatus.PENDING.value,
        )

        return await self.repository.create_appeal(appeal)

    async def get_my_appeal(
        self,
        *,
        post_id: UUID,
        user_id: UUID,
    ) -> PostAppeal | None:
        return await self.repository.get_appeal_by_post_and_user(
            post_id,
            user_id,
        )

    async def list_my_appeals(
        self,
        *,
        user_id: UUID,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[PostAppeal], int]:
        return await self.repository.list_appeals_of_user(
            user_id=user_id,
            offset=offset,
            limit=limit,
        )

    # ============================================================
    # User side: reports
    # ============================================================

    async def submit_report(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
        category: str,
        description: str,
    ) -> PostReport:
        """Report a post owned by somebody else."""

        self._ensure_post_can_be_moderated(
            post=post,
            user_id=user_id,
            label="report",
        )

        description = (description or "").strip()

        existing = await self.repository.get_report_by_post_and_user(
            post.id,
            user_id,
        )

        if existing is not None:
            if existing.status in ACTIVE_STATUSES:
                raise ModerationError(
                    "Your report for this post is already under review"
                )

            existing.category = category
            existing.description = description
            existing.status = ReportStatus.PENDING.value
            existing.admin_notes = None
            existing.action_taken = None
            existing.reviewed_by = None
            existing.reviewed_at = None

            return await self.repository.update_report(existing)

        report = PostReport(
            post_id=post.id,
            user_id=user_id,
            category=category,
            description=description,
            status=ReportStatus.PENDING.value,
        )

        return await self.repository.create_report(report)

    async def list_my_reports(
        self,
        *,
        user_id: UUID,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[PostReport], int]:
        return await self.repository.list_reports_of_user(
            user_id=user_id,
            offset=offset,
            limit=limit,
        )

    def _ensure_post_can_be_moderated(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
        label: str,
    ) -> None:
        """Shared guard for appeals and reports."""

        if post.user_id == user_id:
            raise ModerationError(
                f"You cannot file a {label} against your own post"
            )

        if post.visibility_state == PostVisibilityState.DELETED.value:
            raise ModerationError(
                "This post is no longer available"
            )

    async def post_was_removed_by_moderation(
        self,
        post_id: UUID,
    ) -> bool:
        """True when moderation hid/deleted this post after a review.

        Used by the community router so an owner cannot simply "restore"
        a post that was removed because of an appeal or a report.
        """

        return await self.repository.has_post_moderation_action(
            post_id,
            [
                AdminActionType.POST_DELETED,
                AdminActionType.POST_HIDDEN,
                AdminActionType.POST_PERMANENTLY_DELETED,
            ],
        )

    # ============================================================
    # Admin: appeals
    # ============================================================

    async def list_admin_appeals(
        self,
        **filters,
    ) -> tuple[list[PostAppeal], int]:
        return await self.repository.list_appeals(**filters)

    async def appeal_stats(self) -> dict[str, int]:
        return await self.repository.count_appeals_by_status()

    async def get_appeal(
        self,
        appeal_id: UUID,
    ) -> PostAppeal | None:
        return await self.repository.get_appeal(appeal_id)

    async def appeal_actions(
        self,
        appeal_id: UUID,
    ) -> list[AdminActionLog]:
        return await self.repository.list_action_logs(
            entity_type=AdminActionEntity.APPEAL,
            entity_id=appeal_id,
        )

    async def update_appeal_status(
        self,
        *,
        appeal: PostAppeal,
        admin_user,
        status: str,
        admin_notes: str | None = None,
    ) -> PostAppeal:
        """Move an appeal through its lifecycle (never touches the post)."""

        self._ensure_transition(
            current=appeal.status,
            target=status,
            closed=CLOSED_STATUSES,
        )

        appeal.status = status

        if admin_notes:
            appeal.admin_notes = admin_notes

        if status == AppealStatus.PENDING.value:
            appeal.reviewed_by = None
            appeal.reviewed_at = None
        else:
            appeal.reviewed_by = admin_user.id
            appeal.reviewed_at = datetime.now(timezone.utc)

        await self.repository.add_action_log(
            self._build_log(
                admin_user=admin_user,
                entity_type=AdminActionEntity.APPEAL,
                entity_id=appeal.id,
                action=AdminActionType.STATUS_CHANGED,
                notes=admin_notes,
            )
        )

        updated = await self.repository.update_appeal(appeal)

        await self._notify_appeal_owner_of_decision(
            appeal=updated,
            admin_notes=admin_notes,
        )

        return updated

    async def apply_appeal_post_action(
        self,
        *,
        appeal: PostAppeal,
        admin_user,
        action: str,
        notes: str | None = None,
        community_service,
    ) -> CommunityPost | None:
        """Apply the admin decision to the post itself.

        Deliberately separate from ``update_appeal_status``: changing the
        appeal status alone never hides or deletes a post.
        """

        post = await self.community_repository.get_post(appeal.post_id)

        if post is None:
            raise ModerationError("Post not found")

        log_action = await self._apply_post_action(
            post=post,
            admin_user=admin_user,
            action=action,
            notes=notes,
            entity_type=AdminActionEntity.APPEAL,
            entity_id=appeal.id,
            community_service=community_service,
        )

        appeal.action_taken = self._appeal_action_value(action)

        await self.repository.update_appeal(appeal)

        if log_action is not None:
            await self._notify_post_owner_of_action(
                post=post,
                action=action,
                notes=notes,
            )

        return post

    # ============================================================
    # Admin: reports
    # ============================================================

    async def list_admin_reports(
        self,
        **filters,
    ) -> tuple[list[PostReport], int]:
        return await self.repository.list_reports(**filters)

    async def report_stats(self) -> dict[str, int]:
        return await self.repository.count_reports_by_status()

    async def get_report(
        self,
        report_id: UUID,
    ) -> PostReport | None:
        return await self.repository.get_report(report_id)

    async def report_actions(
        self,
        report_id: UUID,
    ) -> list[AdminActionLog]:
        return await self.repository.list_action_logs(
            entity_type=AdminActionEntity.REPORT,
            entity_id=report_id,
        )

    async def update_report_status(
        self,
        *,
        report: PostReport,
        admin_user,
        status: str,
        admin_notes: str | None = None,
    ) -> PostReport:
        self._ensure_transition(
            current=report.status,
            target=status,
            closed=CLOSED_STATUSES,
        )

        report.status = status

        if admin_notes:
            report.admin_notes = admin_notes

        if status == ReportStatus.PENDING.value:
            report.reviewed_by = None
            report.reviewed_at = None
        else:
            report.reviewed_by = admin_user.id
            report.reviewed_at = datetime.now(timezone.utc)

        await self.repository.add_action_log(
            self._build_log(
                admin_user=admin_user,
                entity_type=AdminActionEntity.REPORT,
                entity_id=report.id,
                action=AdminActionType.STATUS_CHANGED,
                notes=admin_notes,
            )
        )

        updated = await self.repository.update_report(report)

        await self._notify_reporter_of_decision(
            report=updated,
            admin_notes=admin_notes,
        )

        return updated

    async def apply_report_post_action(
        self,
        *,
        report: PostReport,
        admin_user,
        action: str,
        notes: str | None = None,
        community_service,
    ) -> CommunityPost | None:
        post = await self.community_repository.get_post(report.post_id)

        if post is None:
            raise ModerationError("Post not found")

        log_action = await self._apply_post_action(
            post=post,
            admin_user=admin_user,
            action=action,
            notes=notes,
            entity_type=AdminActionEntity.REPORT,
            entity_id=report.id,
            community_service=community_service,
        )

        report.action_taken = self._report_action_value(action)

        await self.repository.update_report(report)

        if log_action is not None:
            await self._notify_post_owner_of_action(
                post=post,
                action=action,
                notes=notes,
            )

        return post

    # ============================================================
    # Shared helpers
    # ============================================================

    def _ensure_transition(
        self,
        *,
        current: str,
        target: str,
        closed: set[str],
    ) -> None:
        current_value = getattr(current, "value", current)
        target_value = getattr(target, "value", target)

        if current_value == target_value:
            return

        if current_value in closed:
            raise ModerationError(
                "This request is already closed"
            )

        allowed = STATUS_TRANSITIONS.get(current_value, set())

        if target_value not in allowed:
            raise ModerationError(
                f"Invalid status transition: {current_value} -> "
                f"{target_value}"
            )

    def _build_log(
        self,
        *,
        admin_user,
        entity_type: AdminActionEntity,
        entity_id: UUID,
        action: AdminActionType,
        notes: str | None = None,
    ) -> AdminActionLog:
        admin_email = getattr(admin_user, "email", None)
        admin_id = getattr(admin_user, "id", None)

        return AdminActionLog(
            admin_user_id=admin_id,
            admin_email=admin_email,
            entity_type=entity_type,
            entity_id=entity_id,
            action=action,
            notes=notes,
            created_at=datetime.now(timezone.utc),
        )

    async def _apply_post_action(
        self,
        *,
        post: CommunityPost,
        admin_user,
        action: str,
        notes: str | None,
        entity_type: AdminActionEntity,
        entity_id: UUID,
        community_service,
    ) -> bool:
        """Apply the post decision and log it. Returns True if the post
        was actually hidden/deleted (so the owner gets notified)."""

        action = (action or "").upper()

        notify_owner = False

        if action == AppealPostAction.DELETE_POST.value:
            if post.visibility_state != PostVisibilityState.DELETED.value:
                await community_service.soft_delete_post(
                    post=post,
                    user_id=post.user_id,
                )

            log_action = AdminActionType.POST_DELETED
            notify_owner = True

        elif action == AppealPostAction.HIDE_POST.value:
            if post.visibility_state != PostVisibilityState.HIDDEN.value:
                await community_service.hide_post(
                    post=post,
                    user_id=post.user_id,
                )

            log_action = AdminActionType.POST_HIDDEN
            notify_owner = True

        elif action == AppealPostAction.NONE.value:
            log_action = AdminActionType.POST_LEFT_AS_IS

        else:
            log_action = AdminActionType.POST_LEFT_AS_IS

        await self.repository.add_action_log(
            self._build_log(
                admin_user=admin_user,
                entity_type=entity_type,
                entity_id=entity_id,
                action=log_action,
                notes=notes,
            )
        )

        return notify_owner

    def _appeal_action_value(
        self,
        action: str,
    ) -> AppealPostAction:
        action = (action or "").upper()

        try:
            return AppealPostAction(action)
        except ValueError:
            return AppealPostAction.LEAVE_AS_IS

    def _report_action_value(
        self,
        action: str,
    ) -> ReportPostAction:
        action = (action or "").upper()

        try:
            return ReportPostAction(action)
        except ValueError:
            return ReportPostAction.LEAVE_AS_IS

    # ============================================================
    # Notifications (existing in-app + push infrastructure)
    # ============================================================

    APPEAL_MESSAGES = {
        AppealStatus.UNDER_REVIEW.value: (
            "طعنك قيد المراجعة",
            "تم استلام طعنك على تقييم المنشور، وهو الآن قيد المراجعة "
            "من فريق WAYN.",
            "APPEAL_UNDER_REVIEW",
        ),
        AppealStatus.RESOLVED.value: (
            "تم قبول طعنك",
            "راجعنا طعنك على التقييم واتخذنا الإجراء المناسب. "
            "شكرًا لمساعدتك في تحسين WAYN 💚",
            "APPEAL_ACCEPTED",
        ),
        AppealStatus.REJECTED.value: (
            "تم رفض طعنك",
            "راجعنا طعنك على التقييم ولم نجد ما يستدعي التعديل.",
            "APPEAL_REJECTED",
        ),
        AppealStatus.CANCELLED.value: (
            "تم إلغاء طعنك",
            "تم إلغاء طلب الطعن على المنشور.",
            "APPEAL_CANCELLED",
        ),
    }

    REPORT_MESSAGES = {
        ReportStatus.UNDER_REVIEW.value: (
            "بلاغك قيد المراجعة",
            "تم استلام بلاغك وهو الآن قيد المراجعة من فريق WAYN.",
            "REPORT_UNDER_REVIEW",
        ),
        ReportStatus.RESOLVED.value: (
            "تمت معالجة بلاغك",
            "راجعنا البلاغ الذي أرسلته واتخذنا الإجراء المناسب. "
            "شكرًا لمساعدتك في الحفاظ على مجتمع WAYN 💚",
            "REPORT_RESOLVED",
        ),
        ReportStatus.REJECTED.value: (
            "تم رفض بلاغك",
            "راجعنا البلاغ الذي أرسلته ولم نجد ما يستدعي اتخاذ إجراء.",
            "REPORT_REJECTED",
        ),
        ReportStatus.CANCELLED.value: (
            "تم إلغاء بلاغك",
            "تم إلغاء البلاغ الذي أرسلته.",
            "REPORT_CANCELLED",
        ),
    }

    async def _notify_appeal_owner_of_decision(
        self,
        *,
        appeal: PostAppeal,
        admin_notes: str | None,
    ) -> None:
        status = getattr(appeal.status, "value", appeal.status)
        message = self.APPEAL_MESSAGES.get(status)

        if message is None:
            return

        title, body, notification_type = message

        if admin_notes and status == AppealStatus.REJECTED.value:
            body = f"{body}\nملاحظة: {admin_notes}"

        await self._notify(
            user_id=appeal.user_id,
            notification_type=notification_type,
            title=title,
            body=body,
            data={
                "appeal_id": str(appeal.id),
                "post_id": str(appeal.post_id),
                "status": status,
                "action_taken": getattr(
                    appeal.action_taken, "value", appeal.action_taken
                ),
            },
        )

    async def _notify_reporter_of_decision(
        self,
        *,
        report: PostReport,
        admin_notes: str | None,
    ) -> None:
        status = getattr(report.status, "value", report.status)
        message = self.REPORT_MESSAGES.get(status)

        if message is None:
            return

        title, body, notification_type = message

        if admin_notes and status == ReportStatus.REJECTED.value:
            body = f"{body}\nملاحظة: {admin_notes}"

        await self._notify(
            user_id=report.user_id,
            notification_type=notification_type,
            title=title,
            body=body,
            data={
                "report_id": str(report.id),
                "post_id": str(report.post_id),
                "status": status,
                "action_taken": getattr(
                    report.action_taken, "value", report.action_taken
                ),
            },
        )

    async def _notify_post_owner_of_action(
        self,
        *,
        post: CommunityPost,
        action: str,
        notes: str | None,
    ) -> None:
        action = (action or "").upper()

        if action == AppealPostAction.DELETE_POST.value:
            title = "تم حذف منشورك"
            body = (
                "تم حذف منشورك بعد مراجعة طعن/بلاغ متعلق به من قبل "
                "فريق WAYN."
            )
            notification_type = "POST_DELETED_BY_MODERATION"
        elif action == AppealPostAction.HIDE_POST.value:
            title = "تم إخفاء منشورك"
            body = (
                "تم إخفاء منشورك بعد مراجعة طعن/بلاغ متعلق به من قبل "
                "فريق WAYN."
            )
            notification_type = "POST_HIDDEN_BY_MODERATION"
        else:
            return

        if notes:
            body = f"{body}\nملاحظة: {notes}"

        await self._notify(
            user_id=post.user_id,
            notification_type=notification_type,
            title=title,
            body=body,
            data={
                "post_id": str(post.id),
                "action": action,
            },
        )

    async def _notify(
        self,
        *,
        user_id: UUID,
        notification_type: str,
        title: str,
        body: str,
        data: dict,
    ) -> None:
        """Create an in-app notification and (best effort) a push.

        Mirrors the contribution notification flow: the in-app row is part
        of the transaction while the push never rolls anything back.
        """

        from app.models.social import UserNotification

        self.session.add(
            UserNotification(
                user_id=user_id,
                type=notification_type,
                source="moderation",
                text=body,
                data=data,
                is_read=False,
                created_at=datetime.now(timezone.utc),
            )
        )

        # Commit the in-app notification row so it survives even if the
        # best-effort push below raises.  Without this, the row sits only in
        # the current session and is rolled back when the request-scoped
        # session (core.database.get_session) is torn down.
        await self.session.commit()

        try:
            devices = await self.device_repository.get_active_by_user(
                user_id
            )

            tokens = [d.fcm_token for d in devices if d.fcm_token]

            if tokens:
                fcm_service.send_push(
                    tokens=tokens,
                    title=title,
                    body=body,
                )
        except Exception:
            # Push is best-effort only.
            pass