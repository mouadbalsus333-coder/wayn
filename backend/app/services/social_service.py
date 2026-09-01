"""Business logic for follows and notifications."""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social import UserFollow, UserNotification
from app.models.user import User
from app.repositories.social_repository import SocialRepository
from app.repositories.user.repository import UserRepository


class SocialService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = SocialRepository(session)
        self.user_repository = UserRepository(session)

    # ============================================================
    # Follow
    # ============================================================

    async def follow(
        self,
        *,
        follower_id: UUID,
        target_id: UUID,
    ) -> tuple[bool, int]:
        """Follow target_id. Returns (did_follow, followers_count)."""
        if follower_id == target_id:
            raise ValueError("You cannot follow yourself")

        target = await self.user_repository.get_by_id(target_id)
        if target is None:
            raise ValueError("User not found")

        existing = await self.repository.get_follow(
            follower_id,
            target_id,
        )

        if existing is not None:
            followers = await self.repository.count_followers(target_id)
            return False, followers

        await self.repository.create_follow(
            follower_id,
            target_id,
        )

        # إنشاء إشعار داخل نفس الـ transaction.
        await self._notify_follow(
            actor_id=follower_id,
            target=target,
        )

        followers = await self.repository.count_followers(target_id)
        return True, followers

    async def unfollow(
        self,
        *,
        follower_id: UUID,
        target_id: UUID,
    ) -> tuple[bool, int]:
        """Unfollow target_id. Returns (did_unfollow, followers_count)."""
        existing = await self.repository.get_follow(
            follower_id,
            target_id,
        )

        if existing is None:
            followers = await self.repository.count_followers(target_id)
            return False, followers

        await self.repository.delete_follow(existing)

        followers = await self.repository.count_followers(target_id)
        return True, followers

    async def is_following(
        self,
        *,
        follower_id: UUID,
        target_id: UUID,
    ) -> bool:
        if follower_id == target_id:
            return False
        return await self.repository.is_following(
            follower_id,
            target_id,
        )

    # ============================================================
    # Public profile
    # ============================================================

    async def get_public_profile(
        self,
        *,
        viewer_id: UUID,
        target_id: UUID,
        ratings_count: int,
    ) -> dict:
        user = await self.user_repository.get_by_id(target_id)
        if user is None:
            raise ValueError("User not found")

        followers = await self.repository.count_followers(target_id)
        following = await self.repository.count_following(target_id)

        return {
            "id": user.id,
            "username": user.username,
            "full_name": user.full_name,
            "avatar_id": user.avatar_id,
            "bio": user.bio,
            "points": int(user.points) if user.points else 0,
            "followers_count": followers,
            "following_count": following,
            "ratings_count": ratings_count,
            "is_following": await self.is_following(
                follower_id=viewer_id,
                target_id=target_id,
            ),
            "is_owner": viewer_id == target_id,
        }

    async def count_followers(
        self,
        user_id: UUID,
    ) -> int:
        return await self.repository.count_followers(user_id)

    # ============================================================
    # Notifications
    # ============================================================

    async def _notify_follow(
        self,
        *,
        actor_id: UUID,
        target: User,
    ) -> None:
        actor = await self.user_repository.get_by_id(actor_id)
        if actor is None:
            return

        display_name = actor.full_name or actor.username or "مستخدم"

        notification = UserNotification(
            user_id=target.id,
            actor_user_id=actor_id,
            type="FOLLOW",
            text=f"قام {display_name} بمتابعتك",
            data={
                "actor_id": str(actor_id),
                "actor_name": display_name,
            },
        )

        await self.repository.create_notification(notification)

    async def list_notifications(
        self,
        *,
        user_id: UUID,
        offset: int = 0,
        limit: int = 50,
    ) -> list[dict]:
        notifications = await self.repository.list_notifications(
            user_id,
            offset=offset,
            limit=limit,
        )

        result: list[dict] = []

        for notification in notifications:
            actor_name = None
            actor_avatar = None

            if notification.actor_user_id is not None:
                actor = await self.user_repository.get_by_id(
                    notification.actor_user_id
                )
                if actor is not None:
                    actor_name = actor.full_name or actor.username
                    actor_avatar = actor.avatar_id

            result.append(
                {
                    "id": notification.id,
                    "type": notification.type,
                    "text": notification.text,
                    "actor_name": actor_name,
                    "actor_avatar": actor_avatar,
                    "is_read": notification.is_read,
                    "created_at": notification.created_at,
                }
            )

        return result

    async def unread_count(
        self,
        *,
        user_id: UUID,
    ) -> int:
        return await self.repository.count_unread(user_id)

    async def mark_read(
        self,
        *,
        user_id: UUID,
        notification_id: UUID,
    ) -> bool:
        notification = await self.repository.get_notification(
            notification_id,
            user_id,
        )

        if notification is None or notification.is_read:
            return False

        await self.repository.mark_notification_read(notification)
        return True
