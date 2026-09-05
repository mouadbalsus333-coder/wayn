from datetime import datetime, timezone
from uuid import UUID

from geoalchemy2.elements import WKTElement
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password, verify_password
from app.models.user import User
from app.repositories.user.repository import UserRepository
from app.schemas.admin_regular_user import AdminRegularUserRead
from app.services.wallet.service import WalletService


class UserService:
    def __init__(
        self,
        session: AsyncSession,
    ) -> None:
        self.session = session
        self.repository = UserRepository(session)
        self.wallet_service = WalletService(session)

    # ============================================================
    # Basic lookups
    # ============================================================

    async def get_by_id(
        self,
        user_id: UUID,
    ) -> User | None:
        return await self.repository.get_by_id(user_id)

    async def get_by_email(
        self,
        email: str,
    ) -> User | None:
        return await self.repository.get_by_email(email)

    async def get_by_username(
        self,
        username: str,
    ) -> User | None:
        return await self.repository.get_by_username(username)

    async def get_by_phone(
        self,
        phone: str,
    ) -> User | None:
        return await self.repository.get_by_phone(phone)

    async def get_by_google_id(
        self,
        google_id: str,
    ) -> User | None:
        return await self.repository.get_by_google_id(google_id)

    async def list_admin_users(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
        search: str | None = None,
        account_status=None,
        is_active: bool | None = None,
        is_verified: bool | None = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> tuple[list[AdminRegularUserRead], int]:
        users = await self.repository.list_users(
            offset=offset,
            limit=limit,
            search=search,
            account_status=account_status,
            is_active=is_active,
            is_verified=is_verified,
            sort_by=sort_by,
            sort_order=sort_order,
        )
        total = await self.repository.count_users(
            search=search,
            account_status=account_status,
            is_active=is_active,
            is_verified=is_verified,
        )
        return [AdminRegularUserRead.model_validate(user) for user in users], total

    async def get_admin_user(
        self,
        user_id: UUID,
    ) -> AdminRegularUserRead | None:
        user = await self.repository.get_by_id(user_id)
        return AdminRegularUserRead.model_validate(user) if user else None

    async def update_admin_user_status(
        self,
        user: User,
        *,
        account_status,
        is_active: bool | None,
        reason: str | None,
        changed_by: int,
        suspended_until=None,
    ) -> AdminRegularUserRead:
        if account_status is not None:
            user.account_status = account_status
        if is_active is not None:
            user.is_active = is_active
        user.status_reason = reason
        user.suspended_until = suspended_until
        user.status_changed_by = changed_by
        user.status_changed_at = datetime.now(timezone.utc)
        user.token_version += 1
        await self.session.commit()
        await self.session.refresh(user)
        return AdminRegularUserRead.model_validate(user)

    # ============================================================
    # Registration
    # ============================================================

    async def register(
        self,
        email: str,
        password: str,
        full_name: str,
        username: str,
        phone: str | None = None,
        avatar_id: str | None = None,
    ) -> User:
        existing_email = await self.repository.get_by_email(
            email
        )

        if existing_email is not None:
            raise ValueError(
                "Email is already registered"
            )

        existing_username = (
            await self.repository.get_by_username(
                username
            )
        )

        if existing_username is not None:
            raise ValueError(
                "Username is already taken"
            )

        if phone:
            existing_phone = (
                await self.repository.get_by_phone(
                    phone
                )
            )

            if existing_phone is not None:
                raise ValueError(
                    "Phone number is already registered"
                )

        user = User(
            email=email,
            password_hash=hash_password(password),
            full_name=full_name,
            username=username,
            phone=phone,
            avatar_id=avatar_id,
            is_verified=False,
        )

        try:
            # Create the user without committing.
            user = await self.repository.create(user)

            # Create the wallet in the same transaction.
            await self.wallet_service.get_or_create_wallet(
                user.id
            )

            # Commit User + Wallet atomically.
            await self.session.commit()

            # Refresh after commit.
            await self.session.refresh(user)

            return user

        except Exception:
            await self.session.rollback()
            raise

    # ============================================================
    # Authentication
    # ============================================================

    async def authenticate(
        self,
        email: str,
        password: str,
    ) -> User | None:
        user = await self.repository.get_by_email(
            email
        )

        if user is None:
            return None

        if not user.password_hash:
            return None

        if not verify_password(
            password,
            user.password_hash,
        ):
            return None

        if not user.is_active:
            return None

        return user

    # ============================================================
    # Email verification
    # ============================================================

    async def verify_email(
        self,
        user: User,
    ) -> User:
        if not user.is_active:
            raise ValueError(
                "User account is not active"
            )

        if user.is_verified:
            return user

        user.is_verified = True

        return await self.repository.save(user)

    # ============================================================
    # Password reset
    # ============================================================

    async def reset_password(
        self,
        user: User,
        new_password: str,
    ) -> User:
        if not user.is_active:
            raise ValueError(
                "User account is not active"
            )

        user.password_hash = hash_password(
            new_password
        )

        # Invalidate all existing JWT sessions.
        user.token_version += 1

        return await self.repository.save(user)

    # ============================================================
    # Location
    # ============================================================

    async def update_location(
        self,
        user: User,
        latitude: float,
        longitude: float,
        source: str,
    ) -> User:
        user.latitude = latitude
        user.longitude = longitude
        user.location_source = source

        user.location = WKTElement(
            f"POINT({longitude} {latitude})",
            srid=4326,
        )

        return await self.repository.save(user)

    # ============================================================
    # Profile
    # ============================================================

    async def update_profile(
        self,
        user: User,
        full_name: str | None = None,
        username: str | None = None,
        phone: str | None = None,
        avatar_id: str | None = None,
        bio: str | None = None,
    ) -> User:
        if (
            username is not None
            and username != user.username
        ):
            existing_username = (
                await self.repository.get_by_username(
                    username
                )
            )

            if (
                existing_username is not None
                and existing_username.id != user.id
            ):
                raise ValueError(
                    "Username is already taken"
                )

            user.username = username

        if (
            phone is not None
            and phone != user.phone
        ):
            existing_phone = (
                await self.repository.get_by_phone(
                    phone
                )
            )

            if (
                existing_phone is not None
                and existing_phone.id != user.id
            ):
                raise ValueError(
                    "Phone number is already registered"
                )

            user.phone = phone

        if full_name is not None:
            user.full_name = full_name

        if avatar_id is not None:
            user.avatar_id = avatar_id

        if bio is not None:
            user.bio = bio

        return await self.repository.save(user)

    # ============================================================
    # Password
    # ============================================================

    async def change_password(
        self,
        user: User,
        current_password: str,
        new_password: str,
    ) -> None:
        if not user.password_hash:
            raise ValueError(
                "Password authentication is not available"
            )

        if not verify_password(
            current_password,
            user.password_hash,
        ):
            raise ValueError(
                "Current password is incorrect"
            )

        if current_password == new_password:
            raise ValueError(
                "New password must be different "
                "from current password"
            )

        user.password_hash = hash_password(
            new_password
        )

        # Invalidate all existing JWT sessions.
        await self.repository.increment_token_version(
            user
        )
