"""Business logic for WAYN Community."""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.community import (
    CommunityComment,
    CommunityPost,
)
from app.repositories.community_repository import (
    CommunityRepository,
)
from app.services.media.media_service import media_service


class CommunityService:
    """Business logic for community posts, likes, saves, and comments."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = CommunityRepository(session)

    # ============================================================
    # Posts
    # ============================================================

    async def create_post(
        self,
        *,
        user_id: UUID,
        place_id: UUID,
        text: str | None,
        image_url: str | None,
        rating,
    ) -> CommunityPost:
        post = CommunityPost(
            user_id=user_id,
            place_id=place_id,
            text=text.strip() if text else None,
            image_url=image_url,
            rating=rating,
        )

        created_post = await self.repository.create_post(post)

        if rating is not None and place_id is not None:
            await self.repository.recalculate_place_rating(place_id)

        return created_post

    async def get_post(
        self,
        post_id: UUID,
    ) -> CommunityPost | None:
        return await self.repository.get_post(post_id)

    async def list_posts(
        self,
        *,
        place_id: UUID | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> list[CommunityPost]:
        return await self.repository.list_posts(
            place_id=place_id,
            offset=offset,
            limit=limit,
        )

    async def list_saved_posts(
        self,
        *,
        user_id: UUID,
        offset: int = 0,
        limit: int = 20,
    ) -> list[CommunityPost]:
        return await self.repository.list_saved_posts(
            user_id,
            offset=offset,
            limit=limit,
        )

    async def update_post(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
        text: str | None,
        image_url: str | None,
        rating,
    ) -> CommunityPost:
        if post.user_id != user_id:
            raise ValueError(
                "You can only update your own post"
            )

        old_image_url = post.image_url

        if text is not None:
            post.text = text.strip() or None

        if image_url is not None:
            post.image_url = image_url

        rating_changed = False

        if rating is not None and post.rating != rating:
            post.rating = rating
            rating_changed = True

        if not post.text and not post.image_url:
            raise ValueError(
                "Post must contain text or image"
            )

        updated_post = await self.repository.update_post(post)

        if (
            old_image_url
            and old_image_url != post.image_url
        ):
            media_service.delete_file(
                old_image_url,
            )

        if rating_changed and post.place_id is not None:
            await self.repository.recalculate_place_rating(
                post.place_id,
            )

        return updated_post

    async def delete_post(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
    ) -> None:
        if post.user_id != user_id:
            raise ValueError(
                "You can only delete your own post"
            )

        place_id = post.place_id
        image_url = post.image_url

        await self.repository.delete_post(post)

        if image_url:
            media_service.delete_file(
                image_url,
            )

        if place_id is not None:
            await self.repository.recalculate_place_rating(
                place_id,
            )

    # ============================================================
    # Likes
    # ============================================================

    async def like_post(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
    ) -> bool:
        existing = await self.repository.get_like(
            post.id,
            user_id,
        )

        if existing is not None:
            return False

        await self.repository.add_like(
            post.id,
            user_id,
        )

        return True

    async def unlike_post(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
    ) -> bool:
        existing = await self.repository.get_like(
            post.id,
            user_id,
        )

        if existing is None:
            return False

        await self.repository.remove_like(existing)

        return True

    # ============================================================
    # Saves
    # ============================================================

    async def save_post(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
    ) -> bool:
        existing = await self.repository.get_save(
            post.id,
            user_id,
        )

        if existing is not None:
            return False

        await self.repository.add_save(
            post.id,
            user_id,
        )

        return True

    async def unsave_post(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
    ) -> bool:
        existing = await self.repository.get_save(
            post.id,
            user_id,
        )

        if existing is None:
            return False

        await self.repository.remove_save(existing)

        return True

    # ============================================================
    # Comments
    # ============================================================

    async def create_comment(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
        text: str,
    ) -> CommunityComment:
        text = text.strip()

        if not text:
            raise ValueError(
                "Comment cannot be empty"
            )

        comment = CommunityComment(
            post_id=post.id,
            user_id=user_id,
            text=text,
        )

        return await self.repository.create_comment(comment)

    async def list_comments(
        self,
        *,
        post_id: UUID,
        offset: int = 0,
        limit: int = 50,
    ) -> list[CommunityComment]:
        return await self.repository.list_comments(
            post_id,
            offset=offset,
            limit=limit,
        )

    async def delete_comment(
        self,
        *,
        comment: CommunityComment,
        user_id: UUID,
    ) -> None:
        if comment.user_id != user_id:
            raise ValueError(
                "You can only delete your own comment"
            )

        await self.repository.delete_comment(comment)

    # ============================================================
    # Post response state
    # ============================================================

    async def get_post_state(
        self,
        *,
        post: CommunityPost,
        user_id: UUID,
    ) -> dict[str, int | bool]:
        likes_count, saves_count, comments_count = (
            await self.repository.get_post_counts(
                post.id
            )
        )

        return {
            "likes_count": likes_count,
            "saves_count": saves_count,
            "comments_count": comments_count,
            "is_liked": await self.repository.is_liked(
                post.id,
                user_id,
            ),
            "is_saved": await self.repository.is_saved(
                post.id,
                user_id,
            ),
        }