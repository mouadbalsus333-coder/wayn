import math
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_permission
from app.api.routers.community import _build_comment_response, _build_post_response
from app.core.database import get_session
from app.schemas.community import CommunityCommentRead, CommunityPostRead
from app.schemas.pagination import PaginatedResponse
from app.services.community_service import CommunityService


class VisibilityUpdate(BaseModel):
    is_visible: bool


router = APIRouter(
    prefix="/admin/community",
    tags=["Admin Community"],
)


@router.get(
    "/posts",
    response_model=PaginatedResponse[CommunityPostRead],
    dependencies=[Depends(require_permission("community.read"))],
)
async def list_admin_posts(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    search: str | None = Query(default=None, max_length=255),
    is_visible: bool | None = Query(default=None),
    place_id: UUID | None = Query(default=None),
    session: AsyncSession = Depends(get_session),
) -> PaginatedResponse[CommunityPostRead]:
    service = CommunityService(session)
    posts, total = await service.list_admin_posts(
        offset=(page - 1) * limit,
        limit=limit,
        search=search,
        is_visible=is_visible,
        place_id=place_id,
    )
    feed_data = await service.get_posts_feed_data(posts=posts)
    items = [
        await _build_post_response(service, post, None, session, feed_data)
        for post in posts
    ]
    return PaginatedResponse(
        items=items,
        total=total,
        page=page,
        limit=limit,
        pages=math.ceil(total / limit) if total else 0,
    )


@router.patch(
    "/posts/{post_id}/visibility",
    response_model=CommunityPostRead,
    dependencies=[Depends(require_permission("community.moderate"))],
)
async def update_post_visibility(
    post_id: UUID,
    data: VisibilityUpdate,
    session: AsyncSession = Depends(get_session),
) -> CommunityPostRead:
    service = CommunityService(session)
    post = await service.get_post(post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    post = await service.set_post_visibility(post, data.is_visible)
    return await _build_post_response(service, post, None, session)


@router.get(
    "/posts/{post_id}/comments",
    response_model=PaginatedResponse[CommunityCommentRead],
    dependencies=[Depends(require_permission("community.read"))],
)
async def list_admin_comments(
    post_id: UUID,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, ge=1, le=100),
    is_visible: bool | None = Query(default=None),
    session: AsyncSession = Depends(get_session),
) -> PaginatedResponse[CommunityCommentRead]:
    service = CommunityService(session)
    if await service.get_post(post_id) is None:
        raise HTTPException(status_code=404, detail="Post not found")
    comments, total = await service.list_admin_comments(
        post_id,
        offset=(page - 1) * limit,
        limit=limit,
        is_visible=is_visible,
    )
    return PaginatedResponse(
        items=[await _build_comment_response(service, comment) for comment in comments],
        total=total,
        page=page,
        limit=limit,
        pages=math.ceil(total / limit) if total else 0,
    )


@router.patch(
    "/comments/{comment_id}/visibility",
    response_model=CommunityCommentRead,
    dependencies=[Depends(require_permission("community.moderate"))],
)
async def update_comment_visibility(
    comment_id: UUID,
    data: VisibilityUpdate,
    session: AsyncSession = Depends(get_session),
) -> CommunityCommentRead:
    service = CommunityService(session)
    comment = await service.repository.get_comment(comment_id)
    if comment is None:
        raise HTTPException(status_code=404, detail="Comment not found")
    comment = await service.set_comment_visibility(comment, data.is_visible)
    return await _build_comment_response(service, comment)