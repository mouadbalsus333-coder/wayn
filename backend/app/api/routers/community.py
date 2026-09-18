from uuid import UUID, uuid4

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.auth import (
    get_current_user,
    get_optional_current_user,
)
from app.core.config import settings
from app.core.database import get_session
from app.models.community import PostVisibilityState
from app.models.user import User
from app.schemas.community import (
    CommunityCommentCreate,
    CommunityCommentRead,
    CommunityPostCreate,
    CommunityPostRead,
    CommunityPostUpdate,
)
from app.schemas.moderation import (
    AppealCreate,
    AppealRead,
    ReportCreate,
    ReportRead,
)
from app.services.community_service import CommunityService
from app.services.media.media_service import media_service
from app.services.moderation_service import (
    ModerationError,
    ModerationService,
)


router = APIRouter()


# ============================================================
# Helpers
# ============================================================


def _format_image_url(image_url: str | None) -> str | None:
    if not image_url:
        return None

    if image_url.startswith(("http://", "https://")):
        return image_url

    if settings.r2_public_url:
        return (
            f"{settings.r2_public_url.rstrip('/')}/"
            f"{image_url.lstrip('/')}"
        )

    return f"/api/v1/media/{image_url.lstrip('/')}"


async def _build_post_response(
    service: CommunityService,
    post,
    user_id: UUID | None,
    session: AsyncSession,
    feed_data: dict[UUID, dict[str, object]] | None = None,
) -> CommunityPostRead:
    """
    Build a Community post response.

    When feed_data is provided, all related data is taken from
    the batch-loaded result instead of executing database queries
    for the individual post.

    For single-post endpoints, the helper loads batch data for
    that single post.
    """

    if feed_data is None:
        feed_data = await service.get_posts_feed_data(
            posts=[post],
            user_id=user_id,
        )

    data = feed_data.get(post.id)

    if data is None:
        data = {
            "author": None,
            "place": None,
            "author_points": 0,
            "author_followers_count": 0,
            "is_following_author": False,
            "likes_count": 0,
            "saves_count": 0,
            "comments_count": 0,
            "is_liked": False,
            "is_saved": False,
        }

    author = data["author"]
    place = data["place"]

    author_points = int(data["author_points"])
    author_followers_count = int(
        data["author_followers_count"]
    )
    is_following_author = bool(
        data["is_following_author"]
    )

    likes_count = int(data["likes_count"])
    saves_count = int(data["saves_count"])
    comments_count = int(data["comments_count"])

    is_liked = bool(data["is_liked"])
    is_saved = bool(data["is_saved"])

    return CommunityPostRead(
        id=post.id,
        user_id=post.user_id,
        place_id=post.place_id,
        text=post.text,
        image_url=_format_image_url(post.image_url),
        rating=post.rating,
        is_visible=post.is_visible,
        created_at=post.created_at,
        updated_at=post.updated_at,
        author_name=author.full_name if author else None,
        author_username=author.username if author else None,
        author_avatar=author.avatar_id if author else None,
        place_name=place.name if place else None,
        place_city=place.city if place else None,
        author_points=author_points,
        author_followers_count=author_followers_count,
        is_following_author=is_following_author,
        is_owner=(
            user_id is not None
            and post.user_id == user_id
        ),
        likes_count=likes_count,
        saves_count=saves_count,
        comments_count=comments_count,
        is_liked=is_liked,
        is_saved=is_saved,
    )


async def _build_comment_response(
    service: CommunityService,
    comment,
) -> CommunityCommentRead:
    author = await service.repository.get_user(
        comment.user_id
    )

    return CommunityCommentRead(
        id=comment.id,
        post_id=comment.post_id,
        user_id=comment.user_id,
        text=comment.text,
        is_visible=comment.is_visible,
        created_at=comment.created_at,
        updated_at=comment.updated_at,
        author_name=author.full_name if author else None,
        author_username=author.username if author else None,
        author_avatar=author.avatar_id if author else None,
    )


async def _get_post_or_404(
    service: CommunityService,
    post_id: UUID,
):
    post = await service.get_post(post_id)

    if post is None or not post.is_visible:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Post not found",
        )

    return post


# ============================================================
# Community Media
# ============================================================


@router.post(
    "/community/media/image",
    status_code=status.HTTP_201_CREATED,
)
async def upload_community_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
) -> dict[str, str]:
    """
    Upload a Community image to Cloudflare R2.

    The image is processed by ImageService and stored as WEBP.
    The returned value is the R2 object key that can be supplied
    as image_url when creating a Community post.
    """

    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image filename is required",
        )

    try:
        file_bytes = await file.read()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unable to read image file",
        ) from exc

    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image file is empty",
        )

    object_key = (
        f"community/"
        f"{current_user.id}/"
        f"{uuid4()}.webp"
    )

    try:
        stored_key = media_service.upload_image(
            file_bytes=file_bytes,
            object_key=object_key,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Image upload failed",
        ) from exc

    return {
        "image_url": stored_key,
    }


# ============================================================
# Posts
# ============================================================


@router.post(
    "/community/posts",
    response_model=CommunityPostRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_post(
    data: CommunityPostCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CommunityPostRead:
    service = CommunityService(session)

    try:
        post = await service.create_post(
            user_id=current_user.id,
            place_id=data.place_id,
            text=data.text,
            image_url=data.image_url,
            rating=data.rating,
        )
    except Exception:
        await session.rollback()
        raise

    return await _build_post_response(
        service,
        post,
        current_user.id,
        session,
    )


@router.get(
    "/community/posts",
    response_model=list[CommunityPostRead],
)
async def list_posts(
    place_id: UUID | None = Query(default=None),
    user_id: UUID | None = Query(default=None),
    offset: int = Query(
        default=0,
        ge=0,
    ),
    limit: int = Query(
        default=20,
        ge=1,
        le=100,
    ),
    current_user: User | None = Depends(get_optional_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[CommunityPostRead]:
    """
    Public Community feed.

    Guests can read posts and paginate normally.
    Authenticated users additionally receive their personal
    interaction state such as like/save/follow/owner.

    Related post data is loaded in batches to avoid N+1
    database queries.
    """

    service = CommunityService(session)

    posts = await service.list_posts(
        place_id=place_id,
        user_id=user_id,
        offset=offset,
        limit=limit,
    )

    current_user_id = (
        current_user.id
        if current_user is not None
        else None
    )

    feed_data = await service.get_posts_feed_data(
        posts=posts,
        user_id=current_user_id,
    )

    return [
        await _build_post_response(
            service,
            post,
            current_user_id,
            session,
            feed_data,
        )
        for post in posts
    ]


@router.get(
    "/community/posts/saved",
    response_model=list[CommunityPostRead],
)
async def list_saved_posts(
    offset: int = Query(
        default=0,
        ge=0,
    ),
    limit: int = Query(
        default=20,
        ge=1,
        le=100,
    ),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[CommunityPostRead]:
    service = CommunityService(session)

    posts = await service.list_saved_posts(
        user_id=current_user.id,
        offset=offset,
        limit=limit,
    )

    feed_data = await service.get_posts_feed_data(
        posts=posts,
        user_id=current_user.id,
    )

    return [
        await _build_post_response(
            service,
            post,
            current_user.id,
            session,
            feed_data,
        )
        for post in posts
    ]


# ============================================================
# Post lifecycle (owner)
# ============================================================


async def _get_owned_post_or_404(
    service: CommunityService,
    post_id: UUID,
    user_id: UUID,
):
    """Load a post owned by the current user (hidden/deleted included)."""

    post = await service.get_post(post_id)

    if post is None or post.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Post not found",
        )

    return post


@router.get(
    "/community/posts/mine",
    response_model=list[CommunityPostRead],
)
async def list_my_posts_by_state(
    state: str = Query(
        default="DELETED",
        pattern="^(VISIBLE|HIDDEN|DELETED)$",
    ),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[CommunityPostRead]:
    """List the current user's own posts by lifecycle state.

    Powers "المنشورات المحذوفة" (DELETED) and "المنشورات المخفية"
    (HIDDEN) inside the app settings.
    """

    service = CommunityService(session)

    posts, _total = await service.list_user_posts_by_state(
        user_id=current_user.id,
        state=state,
        offset=offset,
        limit=limit,
    )

    feed_data = await service.get_posts_feed_data(
        posts=posts,
        user_id=current_user.id,
    )

    return [
        await _build_post_response(
            service,
            post,
            current_user.id,
            session,
            feed_data,
        )
        for post in posts
    ]


@router.patch(
    "/community/posts/{post_id}/hide",
    response_model=CommunityPostRead,
)
async def hide_post(
    post_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CommunityPostRead:
    service = CommunityService(session)

    post = await _get_owned_post_or_404(
        service,
        post_id,
        current_user.id,
    )

    try:
        post = await service.hide_post(
            post=post,
            user_id=current_user.id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return await _build_post_response(
        service,
        post,
        current_user.id,
        session,
    )


@router.patch(
    "/community/posts/{post_id}/restore",
    response_model=CommunityPostRead,
)
async def restore_post(
    post_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CommunityPostRead:
    service = CommunityService(session)

    post = await _get_owned_post_or_404(
        service,
        post_id,
        current_user.id,
    )

    # A post removed by moderation may not be restored by its owner.
    moderation_service = ModerationService(session)

    if await moderation_service.post_was_removed_by_moderation(post.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This post was removed after a moderation review",
        )

    try:
        post = await service.restore_post(
            post=post,
            user_id=current_user.id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return await _build_post_response(
        service,
        post,
        current_user.id,
        session,
    )


@router.get(
    "/community/posts/{post_id}",
    response_model=CommunityPostRead,
)
async def get_post(
    post_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CommunityPostRead:
    service = CommunityService(session)

    post = await _get_post_or_404(
        service,
        post_id,
    )

    return await _build_post_response(
        service,
        post,
        current_user.id,
        session,
    )


@router.patch(
    "/community/posts/{post_id}",
    response_model=CommunityPostRead,
)
async def update_post(
    post_id: UUID,
    data: CommunityPostUpdate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CommunityPostRead:
    service = CommunityService(session)

    post = await _get_post_or_404(
        service,
        post_id,
    )

    try:
        post = await service.update_post(
            post=post,
            user_id=current_user.id,
            text=data.text,
            image_url=data.image_url,
            rating=data.rating,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
                if "own post" in str(exc)
                else status.HTTP_400_BAD_REQUEST
            ),
            detail=str(exc),
        ) from exc

    return await _build_post_response(
        service,
        post,
        current_user.id,
        session,
    )


@router.delete(
    "/community/posts/{post_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_post(
    post_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    """Soft delete an owned post.

    The post moves to "المنشورات المحذوفة" in the app settings where the
    owner can restore it or delete it permanently.
    """

    service = CommunityService(session)

    post = await _get_owned_post_or_404(
        service,
        post_id,
        current_user.id,
    )

    try:
        await service.soft_delete_post(
            post=post,
            user_id=current_user.id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.delete(
    "/community/posts/{post_id}/permanent",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def permanently_delete_post(
    post_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    """Definitively delete an owned post (no way back)."""

    service = CommunityService(session)

    post = await _get_owned_post_or_404(
        service,
        post_id,
        current_user.id,
    )

    try:
        await service.permanently_delete_post(
            post=post,
            user_id=current_user.id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


# ============================================================
# Likes
# ============================================================


@router.post(
    "/community/posts/{post_id}/like",
    response_model=CommunityPostRead,
)
async def like_post(
    post_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CommunityPostRead:
    service = CommunityService(session)

    post = await _get_post_or_404(
        service,
        post_id,
    )

    await service.like_post(
        post=post,
        user_id=current_user.id,
    )

    return await _build_post_response(
        service,
        post,
        current_user.id,
        session,
    )


@router.delete(
    "/community/posts/{post_id}/like",
    response_model=CommunityPostRead,
)
async def unlike_post(
    post_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CommunityPostRead:
    service = CommunityService(session)

    post = await _get_post_or_404(
        service,
        post_id,
    )

    await service.unlike_post(
        post=post,
        user_id=current_user.id,
    )

    return await _build_post_response(
        service,
        post,
        current_user.id,
        session,
    )


# ============================================================
# Saves
# ============================================================


@router.post(
    "/community/posts/{post_id}/save",
    response_model=CommunityPostRead,
)
async def save_post(
    post_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CommunityPostRead:
    service = CommunityService(session)

    post = await _get_post_or_404(
        service,
        post_id,
    )

    await service.save_post(
        post=post,
        user_id=current_user.id,
    )

    return await _build_post_response(
        service,
        post,
        current_user.id,
        session,
    )


@router.delete(
    "/community/posts/{post_id}/save",
    response_model=CommunityPostRead,
)
async def unsave_post(
    post_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CommunityPostRead:
    service = CommunityService(session)

    post = await _get_post_or_404(
        service,
        post_id,
    )

    await service.unsave_post(
        post=post,
        user_id=current_user.id,
    )

    return await _build_post_response(
        service,
        post,
        current_user.id,
        session,
    )


# ============================================================
# Comments
# ============================================================


@router.post(
    "/community/posts/{post_id}/comments",
    response_model=CommunityCommentRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_comment(
    post_id: UUID,
    data: CommunityCommentCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CommunityCommentRead:
    service = CommunityService(session)

    post = await _get_post_or_404(
        service,
        post_id,
    )

    try:
        comment = await service.create_comment(
            post=post,
            user_id=current_user.id,
            text=data.text,
        )
        return await _build_comment_response(
            service,
            comment,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.get(
    "/community/posts/{post_id}/comments",
    response_model=list[CommunityCommentRead],
)
async def list_comments(
    post_id: UUID,
    offset: int = Query(
        default=0,
        ge=0,
    ),
    limit: int = Query(
        default=50,
        ge=1,
        le=100,
    ),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[CommunityCommentRead]:
    service = CommunityService(session)

    await _get_post_or_404(
        service,
        post_id,
    )

    comments = await service.list_comments(
        post_id=post_id,
        offset=offset,
        limit=limit,
    )

    return [
        await _build_comment_response(
            service,
            comment,
        )
        for comment in comments
    ]


@router.delete(
    "/community/comments/{comment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_comment(
    comment_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    service = CommunityService(session)

    comment = await service.repository.get_comment(
        comment_id,
    )

    if comment is None or not comment.is_visible:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Comment not found",
        )

    try:
        await service.delete_comment(
            comment=comment,
            user_id=current_user.id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exc),
        ) from exc


# ============================================================
# Rating appeals (الطعن في التقييم)
# ============================================================


async def _get_moderatable_post_or_404(
    service: CommunityService,
    post_id: UUID,
):
    """Load a post that can be appealed/reported.

    Deleted posts are treated as gone; hidden posts still exist, so they
    are returned (the service applies the remaining rules).
    """

    post = await service.get_post(post_id)

    if post is None or post.visibility_state == (
        PostVisibilityState.DELETED.value
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Post not found",
        )

    return post


@router.post(
    "/community/posts/{post_id}/appeals",
    response_model=AppealRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_post_appeal(
    post_id: UUID,
    data: AppealCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> AppealRead:
    service = CommunityService(session)

    post = await _get_moderatable_post_or_404(service, post_id)

    moderation = ModerationService(session)

    try:
        appeal = await moderation.submit_appeal(
            post=post,
            user_id=current_user.id,
            type=data.type,
            reason=data.reason,
        )
    except ModerationError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    return AppealRead.model_validate(appeal)


@router.get(
    "/community/posts/{post_id}/appeals/me",
    response_model=AppealRead | None,
)
async def get_my_post_appeal(
    post_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> AppealRead | None:
    """The current user's own appeal for a post (or null)."""

    moderation = ModerationService(session)

    appeal = await moderation.get_my_appeal(
        post_id=post_id,
        user_id=current_user.id,
    )

    if appeal is None:
        return None

    return AppealRead.model_validate(appeal)


@router.get(
    "/community/appeals/mine",
    response_model=list[AppealRead],
)
async def list_my_appeals(
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[AppealRead]:
    moderation = ModerationService(session)

    appeals, _total = await moderation.list_my_appeals(
        user_id=current_user.id,
        offset=offset,
        limit=limit,
    )

    return [AppealRead.model_validate(appeal) for appeal in appeals]


# ============================================================
# Post reports (الإبلاغ عن منشور)
# ============================================================


@router.post(
    "/community/posts/{post_id}/reports",
    response_model=ReportRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_post_report(
    post_id: UUID,
    data: ReportCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> ReportRead:
    service = CommunityService(session)

    post = await _get_moderatable_post_or_404(service, post_id)

    moderation = ModerationService(session)

    try:
        report = await moderation.submit_report(
            post=post,
            user_id=current_user.id,
            category=data.category,
            description=data.description,
        )
    except ModerationError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    return ReportRead.model_validate(report)


@router.get(
    "/community/reports/mine",
    response_model=list[ReportRead],
)
async def list_my_reports(
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[ReportRead]:
    moderation = ModerationService(session)

    reports, _total = await moderation.list_my_reports(
        user_id=current_user.id,
        offset=offset,
        limit=limit,
    )

    return [ReportRead.model_validate(report) for report in reports]