"""Repository for user follows and user notifications."""

from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social import UserFollow, UserNotification


class SocialRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # ============================================================
    # Follows
    # ============================================================

    async def get_follow(
        self,
        follower_id: UUID | str,
        following_id: UUID | str,
    ) -> UserFollow | None:
        result = await self.session.execute(
            select(UserFollow).where(
                UserFollow.follower_id == follower_id,
                UserFollow.following_id == following_id,
            )
        )
        return result.scalar_one_or_none()

    async def create_follow(
        self,
        follower_id: UUID | str,
        following_id: UUID | str,
    ) -> UserFollow:
        follow = UserFollow(
            follower_id=follower_id,
            following_id=following_id,
        )
        self.session.add(follow)
        await self.session.commit()
        await self.session.refresh(follow)
        return follow

    async def delete_follow(
        self,
        follow: UserFollow,
    ) -> None:
        await self.session.delete(follow)
        await self.session.commit()

    async def is_following(
        self,
        follower_id: UUID | str,
        following_id: UUID | str,
    ) -> bool:
        result = await self.session.execute(
            select(UserFollow.id)
            .where(
                UserFollow.follower_id == follower_id,
                UserFollow.following_id == following_id,
            )
            .limit(1)
        )
        return result.scalar_one_or_none() is not None

    async def count_followers(
        self,
        user_id: UUID | str,
    ) -> int:
        result = await self.session.execute(
            select(func.count(UserFollow.id)).where(
                UserFollow.following_id == user_id,
            )
        )
        return int(result.scalar_one())

    async def count_following(
        self,
        user_id: UUID | str,
    ) -> int:
        result = await self.session.execute(
            select(func.count(UserFollow.id)).where(
                UserFollow.follower_id == user_id,
            )
        )
        return int(result.scalar_one())

    # ============================================================
    # Notifications
    # ============================================================

    async def create_notification(
        self,
        notification: UserNotification,
    ) -> UserNotification:
        self.session.add(notification)
        await self.session.commit()
        await self.session.refresh(notification)
        return notification

    async def list_notifications(
        self,
        user_id: UUID | str,
        *,
        offset: int = 0,
        limit: int = 50,
    ) -> list[UserNotification]:
        result = await self.session.execute(
            select(UserNotification)
            .where(UserNotification.user_id == user_id)
            .order_by(UserNotification.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def count_unread(
        self,
        user_id: UUID | str,
    ) -> int:
        result = await self.session.execute(
            select(func.count(UserNotification.id)).where(
                UserNotification.user_id == user_id,
                UserNotification.is_read.is_(False),
            )
        )
        return int(result.scalar_one())

    async def get_notification(
        self,
        notification_id: UUID | str,
        user_id: UUID | str,
    ) -> UserNotification | None:
        result = await self.session.execute(
            select(UserNotification).where(
                UserNotification.id == notification_id,
                UserNotification.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def mark_notification_read(
        self,
        notification: UserNotification,
    ) -> UserNotification:
        from datetime import datetime, timezone

        notification.is_read = True
        notification.read_at = datetime.now(timezone.utc)
        await self.session.commit()
        await self.session.refresh(notification)
        return notification
