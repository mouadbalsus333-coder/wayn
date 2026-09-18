"""Admin moderation endpoints: rating appeals + post reports."""

import math
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_permission
from app.api.routers.community import _format_image_url
from app.core.database import get_session
from app.models.post_appeal import PostAppeal
from app.models.post_report import PostReport
from app.schemas.moderation import (
    AdminActionLogRead,
    AppealAdminListItem,
    AppealAdminRead,
    AppealStatusUpdate,
    ModerationPostPreview,
    ModerationStats,
    PostActionUpdate,
    ReportAdminListItem,
    ReportAdminRead,
    ReportStatusUpdate,
)
from app.schemas.pagination import PaginatedResponse
from app.services.community_service import CommunityService
from app.services.moderation_service import (
    ModerationError,
    ModerationService,
)


router = APIRouter(
    prefix="/admin/moderation",
    tags=["Admin Moderation"],
)


# ============================================================
# Response builders
# ============================================================


async def _build_post_preview(
    service: ModerationService,
    post,
) -> ModerationPostPreview:
    """Post content snapshot (same data the community screens show)."""

    users = await service.repository.get_users_map([post.user_id])
    places = await service.repository.get_places_map([post.place_id])

    author = users.get(post.user_id)
    place = places.get(post.place_id)

    likes_count, saves_count, comments_count = (
        await service.community_repository.get_post_counts(post.id)
    )

    return ModerationPostPreview(
        id=post.id,
        user_id=post.user_id,
        place_id=post.place_id,
        text=post.text,
        image_url=_format_image_url(post.image_url),
        rating=post.rating,
        is_visible=post.is_visible,
        visibility_state=post.visibility_state,
        deleted_at=post.deleted_at,
        hidden_at=post.hidden_at,
        created_at=post.created_at,
        updated_at=post.updated_at,
        author_name=author.full_name if author else None,
        author_username=author.username if author else None,
        author_avatar=author.avatar_id if author else None,
        place_name=place.name if place else None,
        place_city=place.city if place else None,
        likes_count=likes_count,
        saves_count=saves_count,
        comments_count=comments_count,
    )


async def _build_appeal_list_items(
    service: ModerationService,
    appeals: list[PostAppeal],
) -> list[AppealAdminListItem]:
    users = await service.repository.get_users_map(
        [appeal.user_id for appeal in appeals]
    )
    posts = await service.repository.get_posts_map(
        [appeal.post_id for appeal in appeals]
    )

    owners = await service.repository.get_users_map(
        [post.user_id for post in posts.values()]
    )

    items: list[AppealAdminListItem] = []

    for appeal in appeals:
        complainant = users.get(appeal.user_id)
        post = posts.get(appeal.post_id)
        owner = owners.get(post.user_id) if post else None

        items.append(
            AppealAdminListItem(
                id=appeal.id,
                post_id=appeal.post_id,
                user_id=appeal.user_id,
                type=getattr(appeal.type, "value", appeal.type),
                status=getattr(appeal.status, "value", appeal.status),
                reason=appeal.reason,
                action_taken=getattr(
                    appeal.action_taken, "value", appeal.action_taken
                ),
                created_at=appeal.created_at,
                updated_at=appeal.updated_at,
                reviewed_at=appeal.reviewed_at,
                complainant_name=(
                    complainant.full_name if complainant else None
                ),
                complainant_username=(
                    complainant.username if complainant else None
                ),
                post_owner_name=owner.full_name if owner else None,
                post_owner_username=owner.username if owner else None,
            )
        )

    return items


async def _build_appeal_detail(
    service: ModerationService,
    appeal: PostAppeal,
) -> AppealAdminRead:
    users = await service.repository.get_users_map([appeal.user_id])
    admins = await service.repository.get_admins_map([appeal.reviewed_by])

    complainant = users.get(appeal.user_id)

    post = await service.community_repository.get_post(appeal.post_id)

    owner = None

    if post is not None:
        owners = await service.repository.get_users_map([post.user_id])
        owner = owners.get(post.user_id)

    actions = await service.appeal_actions(appeal.id)

    return AppealAdminRead(
        id=appeal.id,
        post_id=appeal.post_id,
        user_id=appeal.user_id,
        type=getattr(appeal.type, "value", appeal.type),
        reason=appeal.reason,
        status=getattr(appeal.status, "value", appeal.status),
        admin_notes=appeal.admin_notes,
        action_taken=getattr(
            appeal.action_taken, "value", appeal.action_taken
        ),
        reviewed_by=appeal.reviewed_by,
        reviewed_by_email=admins.get(appeal.reviewed_by),
        reviewed_at=appeal.reviewed_at,
        created_at=appeal.created_at,
        updated_at=appeal.updated_at,
        complainant_name=complainant.full_name if complainant else None,
        complainant_username=(
            complainant.username if complainant else None
        ),
        complainant_avatar=(
            complainant.avatar_id if complainant else None
        ),
        complainant_email=complainant.email if complainant else None,
        post_owner_id=post.user_id if post else None,
        post_owner_name=owner.full_name if owner else None,
        post_owner_username=owner.username if owner else None,
        post_owner_avatar=owner.avatar_id if owner else None,
        post=(
            await _build_post_preview(service, post)
            if post is not None
            else None
        ),
        actions=[
            AdminActionLogRead.model_validate(action) for action in actions
        ],
    )


def _stats(values: dict[str, int]) -> ModerationStats:
    return ModerationStats(
        total=sum(values.values()),
        pending=values.get("PENDING", 0),
        under_review=values.get("UNDER_REVIEW", 0),
        resolved=values.get("RESOLVED", 0),
        rejected=values.get("REJECTED", 0),
        cancelled=values.get("CANCELLED", 0),
    )


def _moderation_error(exc: ModerationError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=str(exc),
    )


# ============================================================
# Appeals
# ============================================================


@router.get(
    "/appeals/stats",
    response_model=ModerationStats,
    dependencies=[Depends(require_permission("appeals.read"))],
)
async def appeal_stats(
    session: AsyncSession = Depends(get_session),
) -> ModerationStats:
    service = ModerationService(session)
    return _stats(await service.appeal_stats())


@router.get(
    "/appeals",
    response_model=PaginatedResponse[AppealAdminListItem],
    dependencies=[Depends(require_permission("appeals.read"))],
)
async def list_appeals(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    status_filter: str | None = Query(
        default=None,
        alias="status",
        max_length=30,
    ),
    type: str | None = Query(default=None, max_length=30),
    search: str | None = Query(default=None, max_length=255),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    session: AsyncSession = Depends(get_session),
) -> PaginatedResponse[AppealAdminListItem]:
    service = ModerationService(session)

    appeals, total = await service.list_admin_appeals(
        offset=(page - 1) * limit,
        limit=limit,
        status=status_filter,
        type=type,
        search=search,
        created_from=created_from,
        created_to=created_to,
    )

    return PaginatedResponse(
        items=await _build_appeal_list_items(service, appeals),
        total=total,
        page=page,
        limit=limit,
        pages=math.ceil(total / limit) if total else 0,
    )


@router.get(
    "/appeals/{appeal_id}",
    response_model=AppealAdminRead,
    dependencies=[Depends(require_permission("appeals.read"))],
)
async def get_appeal(
    appeal_id: UUID,
    session: AsyncSession = Depends(get_session),
) -> AppealAdminRead:
    service = ModerationService(session)

    appeal = await service.get_appeal(appeal_id)

    if appeal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appeal not found",
        )

    return await _build_appeal_detail(service, appeal)


@router.patch(
    "/appeals/{appeal_id}/status",
    response_model=AppealAdminRead,
)
async def update_appeal_status(
    appeal_id: UUID,
    data: AppealStatusUpdate,
    admin_user=Depends(require_permission("appeals.manage")),
    session: AsyncSession = Depends(get_session),
) -> AppealAdminRead:
    service = ModerationService(session)

    appeal = await service.get_appeal(appeal_id)

    if appeal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appeal not found",
        )

    try:
        appeal = await service.update_appeal_status(
            appeal=appeal,
            admin_user=admin_user,
            status=data.status,
            admin_notes=data.admin_notes,
        )
    except ModerationError as exc:
        raise _moderation_error(exc) from exc

    return await _build_appeal_detail(service, appeal)


@router.post(
    "/appeals/{appeal_id}/post-action",
    response_model=AppealAdminRead,
)
async def apply_appeal_post_action(
    appeal_id: UUID,
    data: PostActionUpdate,
    admin_user=Depends(require_permission("appeals.manage")),
    session: AsyncSession = Depends(get_session),
) -> AppealAdminRead:
    service = ModerationService(session)

    appeal = await service.get_appeal(appeal_id)

    if appeal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appeal not found",
        )

    try:
        await service.apply_appeal_post_action(
            appeal=appeal,
            admin_user=admin_user,
            action=data.action,
            notes=data.notes,
            community_service=CommunityService(session),
        )
    except ModerationError as exc:
        raise _moderation_error(exc) from exc

    return await _build_appeal_detail(service, appeal)


async def _build_report_list_items(
    service: ModerationService,
    reports: list[PostReport],
) -> list[ReportAdminListItem]:
    users = await service.repository.get_users_map(
        [report.user_id for report in reports]
    )
    posts = await service.repository.get_posts_map(
        [report.post_id for report in reports]
    )

    owners = await service.repository.get_users_map(
        [post.user_id for post in posts.values()]
    )

    items: list[ReportAdminListItem] = []

    for report in reports:
        reporter = users.get(report.user_id)
        post = posts.get(report.post_id)
        owner = owners.get(post.user_id) if post else None

        items.append(
            ReportAdminListItem(
                id=report.id,
                post_id=report.post_id,
                user_id=report.user_id,
                category=getattr(
                    report.category, "value", report.category
                ),
                status=getattr(report.status, "value", report.status),
                description=report.description,
                action_taken=getattr(
                    report.action_taken, "value", report.action_taken
                ),
                created_at=report.created_at,
                updated_at=report.updated_at,
                reviewed_at=report.reviewed_at,
                reporter_name=reporter.full_name if reporter else None,
                reporter_username=(
                    reporter.username if reporter else None
                ),
                post_owner_name=owner.full_name if owner else None,
                post_owner_username=owner.username if owner else None,
            )
        )

    return items


async def _build_report_detail(
    service: ModerationService,
    report: PostReport,
) -> ReportAdminRead:
    users = await service.repository.get_users_map([report.user_id])
    admins = await service.repository.get_admins_map([report.reviewed_by])

    reporter = users.get(report.user_id)

    post = await service.community_repository.get_post(report.post_id)

    owner = None

    if post is not None:
        owners = await service.repository.get_users_map([post.user_id])
        owner = owners.get(post.user_id)

    actions = await service.report_actions(report.id)

    return ReportAdminRead(
        id=report.id,
        post_id=report.post_id,
        user_id=report.user_id,
        category=getattr(report.category, "value", report.category),
        description=report.description,
        status=getattr(report.status, "value", report.status),
        admin_notes=report.admin_notes,
        action_taken=getattr(
            report.action_taken, "value", report.action_taken
        ),
        reviewed_by=report.reviewed_by,
        reviewed_by_email=admins.get(report.reviewed_by),
        reviewed_at=report.reviewed_at,
        created_at=report.created_at,
        updated_at=report.updated_at,
        reporter_name=reporter.full_name if reporter else None,
        reporter_username=reporter.username if reporter else None,
        reporter_avatar=reporter.avatar_id if reporter else None,
        reporter_email=reporter.email if reporter else None,
        post_owner_id=post.user_id if post else None,
        post_owner_name=owner.full_name if owner else None,
        post_owner_username=owner.username if owner else None,
        post_owner_avatar=owner.avatar_id if owner else None,
        post=(
            await _build_post_preview(service, post)
            if post is not None
            else None
        ),
        actions=[
            AdminActionLogRead.model_validate(action) for action in actions
        ],
    )


# ============================================================
# Reports
# ============================================================


@router.get(
    "/reports/stats",
    response_model=ModerationStats,
    dependencies=[Depends(require_permission("reports.read"))],
)
async def report_stats(
    session: AsyncSession = Depends(get_session),
) -> ModerationStats:
    service = ModerationService(session)
    return _stats(await service.report_stats())


@router.get(
    "/reports",
    response_model=PaginatedResponse[ReportAdminListItem],
    dependencies=[Depends(require_permission("reports.read"))],
)
async def list_reports(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    status_filter: str | None = Query(
        default=None,
        alias="status",
        max_length=30,
    ),
    category: str | None = Query(default=None, max_length=30),
    search: str | None = Query(default=None, max_length=255),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    session: AsyncSession = Depends(get_session),
) -> PaginatedResponse[ReportAdminListItem]:
    service = ModerationService(session)

    reports, total = await service.list_admin_reports(
        offset=(page - 1) * limit,
        limit=limit,
        status=status_filter,
        category=category,
        search=search,
        created_from=created_from,
        created_to=created_to,
    )

    return PaginatedResponse(
        items=await _build_report_list_items(service, reports),
        total=total,
        page=page,
        limit=limit,
        pages=math.ceil(total / limit) if total else 0,
    )


@router.get(
    "/reports/{report_id}",
    response_model=ReportAdminRead,
    dependencies=[Depends(require_permission("reports.read"))],
)
async def get_report(
    report_id: UUID,
    session: AsyncSession = Depends(get_session),
) -> ReportAdminRead:
    service = ModerationService(session)

    report = await service.get_report(report_id)

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report not found",
        )

    return await _build_report_detail(service, report)


@router.patch(
    "/reports/{report_id}/status",
    response_model=ReportAdminRead,
)
async def update_report_status(
    report_id: UUID,
    data: ReportStatusUpdate,
    admin_user=Depends(require_permission("reports.write")),
    session: AsyncSession = Depends(get_session),
) -> ReportAdminRead:
    service = ModerationService(session)

    report = await service.get_report(report_id)

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report not found",
        )

    try:
        report = await service.update_report_status(
            report=report,
            admin_user=admin_user,
            status=data.status,
            admin_notes=data.admin_notes,
        )
    except ModerationError as exc:
        raise _moderation_error(exc) from exc

    return await _build_report_detail(service, report)


@router.post(
    "/reports/{report_id}/post-action",
    response_model=ReportAdminRead,
)
async def apply_report_post_action(
    report_id: UUID,
    data: PostActionUpdate,
    admin_user=Depends(require_permission("reports.write")),
    session: AsyncSession = Depends(get_session),
) -> ReportAdminRead:
    service = ModerationService(session)

    report = await service.get_report(report_id)

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report not found",
        )

    try:
        await service.apply_report_post_action(
            report=report,
            admin_user=admin_user,
            action=data.action,
            notes=data.notes,
            community_service=CommunityService(session),
        )
    except ModerationError as exc:
        raise _moderation_error(exc) from exc

    return await _build_report_detail(service, report)