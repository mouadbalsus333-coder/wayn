"""Public user profiles and follows API routes."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.models.user import User
from app.repositories.community_repository import CommunityRepository
from app.schemas.social import FollowResult, PublicUserRead
from app.services.social_service import SocialService


router = APIRouter(prefix="/users", tags=["Users"])


def _parse_uuid(user_id: str) -> UUID:
    try:
        return UUID(user_id)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )


# ============================================================
# Public profile
# ============================================================


@router.get(
    "/{user_id}",
    response_model=PublicUserRead,
)
async def get_public_user(
    user_id: str,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> PublicUserRead:
    user_uuid = _parse_uuid(user_id)

    social_service = SocialService(session)
    community_repository = CommunityRepository(session)

    ratings_count = len(
        await community_repository.list_posts(
            user_id=user_uuid,
            offset=0,
            limit=100,
        )
    )

    try:
        profile = await social_service.get_public_profile(
            viewer_id=current_user.id,
            target_id=user_uuid,
            ratings_count=ratings_count,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc

    return PublicUserRead(**profile)


# ============================================================
# Follow / Unfollow
# ============================================================


@router.post(
    "/{user_id}/follow",
    response_model=FollowResult,
    status_code=status.HTTP_200_OK,
)
async def follow_user(
    user_id: str,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> FollowResult:
    user_uuid = _parse_uuid(user_id)

    service = SocialService(session)

    try:
        did_follow, followers = await service.follow(
            follower_id=current_user.id,
            target_id=user_uuid,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return FollowResult(
        user_id=user_uuid,
        is_following=True,
        followers_count=followers,
    )


@router.delete(
    "/{user_id}/follow",
    response_model=FollowResult,
    status_code=status.HTTP_200_OK,
)
async def unfollow_user(
    user_id: str,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> FollowResult:
    user_uuid = _parse_uuid(user_id)

    service = SocialService(session)

    did_unfollow, followers = await service.unfollow(
        follower_id=current_user.id,
        target_id=user_uuid,
    )

    return FollowResult(
        user_id=user_uuid,
        is_following=False,
        followers_count=followers,
    )
