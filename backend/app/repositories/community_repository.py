"""Repository for WAYN Community operations."""

from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.community import (
    CommunityComment,
    CommunityPost,
    CommunityPostLike,
    CommunityPostSave,
)
from app.models.place import Place
from app.models.user import User


class CommunityRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # ============================================================
    # Posts
    # ============================================================

    async def create_post(
        self,
        post: CommunityPost,
    ) -> CommunityPost:
        self.session.add(post)
        await self.session.commit()
        await self.session.refresh(post)
        return post

    async def get_post(
        self,
        post_id: UUID | str,
    ) -> CommunityPost | None:
        result = await self.session.execute(
            select(CommunityPost).where(
                CommunityPost.id == post_id,
            )
        )
        return result.scalar_one_or_none()

    async def list_posts(
        self,
        *,
        place_id: UUID | str | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> list[CommunityPost]:
        query = select(CommunityPost).where(
            CommunityPost.is_visible.is_(True),
        )

        if place_id is not None:
            query = query.where(
                CommunityPost.place_id == place_id,
            )

        query = (
            query
            .order_by(CommunityPost.created_at.desc())
            .offset(offset)
            .limit(limit)
        )

        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def update_post(
        self,
        post: CommunityPost,
    ) -> CommunityPost:
        await self.session.commit()
        await self.session.refresh(post)
        return post

    async def delete_post(
        self,
        post: CommunityPost,
    ) -> None:
        await self.session.delete(post)
        await self.session.commit()

    # ============================================================
    # Likes
    # ============================================================

    async def get_like(
        self,
        post_id: UUID | str,
        user_id: UUID | str,
    ) -> CommunityPostLike | None:
        result = await self.session.execute(
            select(CommunityPostLike).where(
                CommunityPostLike.post_id == post_id,
                CommunityPostLike.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def add_like(
        self,
        post_id: UUID | str,
        user_id: UUID | str,
    ) -> CommunityPostLike:
        like = CommunityPostLike(
            post_id=post_id,
            user_id=user_id,
        )

        self.session.add(like)

        await self.session.commit()
        await self.session.refresh(like)

        return like

    async def remove_like(
        self,
        like: CommunityPostLike,
    ) -> None:
        await self.session.delete(like)
        await self.session.commit()

    # ============================================================
    # Saves
    # ============================================================

    async def get_save(
        self,
        post_id: UUID | str,
        user_id: UUID | str,
    ) -> CommunityPostSave | None:
        result = await self.session.execute(
            select(CommunityPostSave).where(
                CommunityPostSave.post_id == post_id,
                CommunityPostSave.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def add_save(
        self,
        post_id: UUID | str,
        user_id: UUID | str,
    ) -> CommunityPostSave:
        save = CommunityPostSave(
            post_id=post_id,
            user_id=user_id,
        )

        self.session.add(save)

        await self.session.commit()
        await self.session.refresh(save)

        return save

    async def remove_save(
        self,
        save: CommunityPostSave,
    ) -> None:
        await self.session.delete(save)
        await self.session.commit()

    # ============================================================
    # Comments
    # ============================================================

    async def create_comment(
        self,
        comment: CommunityComment,
    ) -> CommunityComment:
        self.session.add(comment)

        await self.session.commit()
        await self.session.refresh(comment)

        return comment

    async def get_comment(
        self,
        comment_id: UUID | str,
    ) -> CommunityComment | None:
        result = await self.session.execute(
            select(CommunityComment).where(
                CommunityComment.id == comment_id,
            )
        )
        return result.scalar_one_or_none()

    async def list_comments(
        self,
        post_id: UUID | str,
        *,
        offset: int = 0,
        limit: int = 50,
    ) -> list[CommunityComment]:
        result = await self.session.execute(
            select(CommunityComment)
            .where(
                CommunityComment.post_id == post_id,
                CommunityComment.is_visible.is_(True),
            )
            .order_by(CommunityComment.created_at.asc())
            .offset(offset)
            .limit(limit)
        )

        return list(result.scalars().all())

    async def delete_comment(
        self,
        comment: CommunityComment,
    ) -> None:
        await self.session.delete(comment)
        await self.session.commit()

    # ============================================================
    # Counts
    # ============================================================

    async def get_post_counts(
        self,
        post_id: UUID | str,
    ) -> tuple[int, int, int]:
        likes_result = await self.session.execute(
            select(func.count(CommunityPostLike.id)).where(
                CommunityPostLike.post_id == post_id,
            )
        )

        saves_result = await self.session.execute(
            select(func.count(CommunityPostSave.id)).where(
                CommunityPostSave.post_id == post_id,
            )
        )

        comments_result = await self.session.execute(
            select(func.count(CommunityComment.id)).where(
                CommunityComment.post_id == post_id,
                CommunityComment.is_visible.is_(True),
            )
        )

        return (
            int(likes_result.scalar_one()),
            int(saves_result.scalar_one()),
            int(comments_result.scalar_one()),
        )

    # ============================================================
    # User state
    # ============================================================

    async def is_liked(
        self,
        post_id: UUID | str,
        user_id: UUID | str,
    ) -> bool:
        result = await self.session.execute(
            select(CommunityPostLike.id)
            .where(
                CommunityPostLike.post_id == post_id,
                CommunityPostLike.user_id == user_id,
            )
            .limit(1)
        )

        return result.scalar_one_or_none() is not None

    async def is_saved(
        self,
        post_id: UUID | str,
        user_id: UUID | str,
    ) -> bool:
        result = await self.session.execute(
            select(CommunityPostSave.id)
            .where(
                CommunityPostSave.post_id == post_id,
                CommunityPostSave.user_id == user_id,
            )
            .limit(1)
        )

        return result.scalar_one_or_none() is not None

    async def list_saved_posts(
        self,
        user_id: UUID | str,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> list[CommunityPost]:
        query = (
            select(CommunityPost)
            .join(
                CommunityPostSave,
                CommunityPostSave.post_id == CommunityPost.id,
            )
            .where(
                CommunityPostSave.user_id == user_id,
                CommunityPost.is_visible.is_(True),
            )
            .order_by(CommunityPostSave.created_at.desc())
            .offset(offset)
            .limit(limit)
        )

        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def get_user(
        self,
        user_id: UUID | str,
    ) -> User | None:
        result = await self.session.execute(
            select(User).where(User.id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_place(
        self,
        place_id: UUID | str,
    ) -> Place | None:
        place_id_str = str(place_id)
        result = await self.session.execute(
            select(Place).where(Place.id == place_id_str)
        )
        return result.scalar_one_or_none()

    async def recalculate_place_rating(
        self,
        place_id: UUID | str,
    ) -> None:
        place_id_str = str(place_id)
        place = await self.get_place(place_id_str)
        if place is None:
            return

        place_uuid = UUID(place_id_str) if isinstance(place_id, str) else place_id

        result = await self.session.execute(
            select(
                func.count(CommunityPost.id),
                func.avg(CommunityPost.rating),
            ).where(
                CommunityPost.place_id == place_uuid,
                CommunityPost.rating.is_not(None),
                CommunityPost.is_visible.is_(True),
            )
        )

        row = result.one_or_none()
        if row is None or row[0] == 0:
            place.rating = 0.0
            place.reviews_count = 0
        else:
            count = int(row[0])
            avg_rating = float(row[1]) if row[1] is not None else None
            place.rating = round(avg_rating, 1) if avg_rating is not None else 0.0
            place.reviews_count = count

        await self.session.commit()