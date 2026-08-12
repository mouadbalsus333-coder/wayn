from datetime import datetime
from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import AccountStatus, User


class UserRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # ============================================================
    # Basic lookups
    # ============================================================

    async def get_by_id(self, user_id: UUID) -> User | None:
        result = await self.session.execute(
            select(User).where(User.id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        result = await self.session.execute(
            select(User).where(User.email == email)
        )
        return result.scalar_one_or_none()

    async def get_by_username(self, username: str) -> User | None:
        result = await self.session.execute(
            select(User).where(User.username == username)
        )
        return result.scalar_one_or_none()

    async def get_by_phone(self, phone: str) -> User | None:
        result = await self.session.execute(
            select(User).where(User.phone == phone)
        )
        return result.scalar_one_or_none()

    async def get_by_google_id(self, google_id: str) -> User | None:
        result = await self.session.execute(
            select(User).where(User.google_id == google_id)
        )
        return result.scalar_one_or_none()

    # ============================================================
    # Admin: list users
    # ============================================================

    async def list_users(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
        search: str | None = None,
        account_status: AccountStatus | None = None,
        is_active: bool | None = None,
        is_verified: bool | None = None,
    ) -> list[User]:
        query = select(User)

        if search:
            search_term = f"%{search.strip()}%"

            query = query.where(
                or_(
                    User.email.ilike(search_term),
                    User.username.ilike(search_term),
                    User.full_name.ilike(search_term),
                    User.phone.ilike(search_term),
                )
            )

        if account_status is not None:
            query = query.where(
                User.account_status == account_status
            )

        if is_active is not None:
            query = query.where(
                User.is_active == is_active
            )

        if is_verified is not None:
            query = query.where(
                User.is_verified == is_verified
            )

        query = (
            query
            .order_by(User.created_at.desc())
            .offset(offset)
            .limit(limit)
        )

        result = await self.session.execute(query)

        return list(result.scalars().all())

    # ============================================================
    # Admin: count users
    # ============================================================

    async def count_users(
        self,
        *,
        search: str | None = None,
        account_status: AccountStatus | None = None,
        is_active: bool | None = None,
        is_verified: bool | None = None,
    ) -> int:
        query = select(func.count(User.id))

        if search:
            search_term = f"%{search.strip()}%"

            query = query.where(
                or_(
                    User.email.ilike(search_term),
                    User.username.ilike(search_term),
                    User.full_name.ilike(search_term),
                    User.phone.ilike(search_term),
                )
            )

        if account_status is not None:
            query = query.where(
                User.account_status == account_status
            )

        if is_active is not None:
            query = query.where(
                User.is_active == is_active
            )

        if is_verified is not None:
            query = query.where(
                User.is_verified == is_verified
            )

        result = await self.session.execute(query)

        return int(result.scalar_one())

    # ============================================================
    # Admin: account status
    # ============================================================

    async def update_account_status(
        self,
        user: User,
        *,
        status: AccountStatus,
        reason: str | None,
        changed_by: int | None,
        suspended_until: datetime | None = None,
    ) -> User:
        user.account_status = status
        user.status_reason = reason
        user.status_changed_at = datetime.utcnow()
        user.status_changed_by = changed_by
        user.suspended_until = suspended_until

        return await self.save(user)

    # ============================================================
    # Authentication invalidation
    # ============================================================

    async def increment_token_version(
        self,
        user: User,
    ) -> User:
        user.token_version += 1

        return await self.save(user)

    # ============================================================
    # Persistence
    # ============================================================

    async def create(self, user: User) -> User:
        self.session.add(user)

        await self.session.commit()
        await self.session.refresh(user)

        return user

    async def save(self, user: User) -> User:
        await self.session.commit()
        await self.session.refresh(user)

        return user