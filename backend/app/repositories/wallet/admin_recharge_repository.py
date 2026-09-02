"""Repository for admin wallet recharge records."""

from datetime import datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.user import User
from app.models.wallet import UserWallet
from app.models.wallet_admin_recharge import (
    WalletAdminRecharge,
    WalletAdminRechargeStatus,
)


class AdminRechargeRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # ============================================================
    # Lookup (wallet + user)
    # ============================================================

    async def _get_wallet_with_user(
        self,
        *conditions,
    ) -> tuple[UserWallet, User] | None:
        """
        Fetch a wallet together with its owner.

        Shared helper for the public lookup methods below. Uses
        populate_existing so a locked re-read inside the recharge
        transaction always sees fresh database state.
        """
        result = await self.session.execute(
            select(UserWallet, User)
            .join(User, UserWallet.user_id == User.id)
            .where(*conditions)
            .execution_options(
                populate_existing=True,
            )
        )

        row = result.first()

        if row is None:
            return None

        return row[0], row[1]

    async def find_wallet_by_number(
        self,
        wallet_number: str,
    ) -> tuple[UserWallet, User] | None:
        """Lookup a wallet by its wallet number."""
        return await self._get_wallet_with_user(
            UserWallet.wallet_number == wallet_number,
        )

    async def find_wallet_by_user_id(
        self,
        user_id: UUID | str,
    ) -> tuple[UserWallet, User] | None:
        """Lookup a wallet by the owner user ID."""
        return await self._get_wallet_with_user(
            UserWallet.user_id == str(user_id),
        )

    # ============================================================
    # Create
    # ============================================================

    async def create_recharge(
        self,
        recharge: WalletAdminRecharge,
    ) -> WalletAdminRecharge:
        """
        Persist a new admin recharge record.

        No commit here: the service owns the transaction so the
        balance update, ledger entry, recharge record, and user
        notification commit atomically together.
        """
        self.session.add(recharge)

        await self.session.flush()
        await self.session.refresh(recharge)

        return recharge

    # ============================================================
    # Single record
    # ============================================================

    async def get_recharge_by_id(
        self,
        recharge_id: UUID | str,
    ) -> WalletAdminRecharge | None:
        """
        Fetch one recharge with its related user, wallet, admin,
        and ledger transaction eagerly loaded.
        """
        result = await self.session.execute(
            select(WalletAdminRecharge)
            .where(WalletAdminRecharge.id == str(recharge_id))
            .options(
                selectinload(WalletAdminRecharge.user),
                selectinload(WalletAdminRecharge.wallet),
                selectinload(WalletAdminRecharge.admin),
                selectinload(WalletAdminRecharge.transaction),
            )
        )

        return result.scalar_one_or_none()

    # ============================================================
    # Idempotency support
    # ============================================================

    async def get_recharge_by_idempotency_key(
        self,
        admin_id: int,
        idempotency_key: str,
        *,
        for_update: bool = False,
    ) -> WalletAdminRecharge | None:
        """
        Find a recharge by admin and idempotency key.

        for_update lets the service lock the existing row while it
        decides how to respond to a duplicate request. The unique
        index uq_wallet_admin_recharges_admin_idempotency remains
        the final protection against race conditions.
        """
        query = select(WalletAdminRecharge).where(
            WalletAdminRecharge.admin_id == admin_id,
            WalletAdminRecharge.idempotency_key == idempotency_key,
        )

        if for_update:
            query = query.with_for_update()

        result = await self.session.execute(query)

        return result.scalar_one_or_none()

    # ============================================================
    # Listing (with pagination + filters)
    # ============================================================

    @staticmethod
    def _list_filters(
        *,
        wallet_number: str | None,
        user_id: UUID | str | None,
        admin_id: int | None,
        status: WalletAdminRechargeStatus | None,
        created_from: datetime | None,
        created_to: datetime | None,
        search: str | None,
    ) -> list:
        """Build the shared WHERE conditions for list + count queries."""
        conditions = []

        if wallet_number is not None:
            conditions.append(
                WalletAdminRecharge.wallet_number == wallet_number,
            )

        if user_id is not None:
            conditions.append(
                WalletAdminRecharge.user_id == str(user_id),
            )

        if admin_id is not None:
            conditions.append(
                WalletAdminRecharge.admin_id == admin_id,
            )

        if status is not None:
            conditions.append(
                WalletAdminRecharge.status == status,
            )

        if created_from is not None:
            conditions.append(
                WalletAdminRecharge.created_at >= created_from,
            )

        if created_to is not None:
            conditions.append(
                WalletAdminRecharge.created_at <= created_to,
            )

        if search:
            pattern = f"%{search}%"
            conditions.append(
                WalletAdminRecharge.wallet_number.ilike(pattern)
                | User.full_name.ilike(pattern)
                | User.username.ilike(pattern)
                | User.phone.ilike(pattern)
            )

        return conditions

    async def list_recharges(
        self,
        *,
        wallet_number: str | None = None,
        user_id: UUID | str | None = None,
        admin_id: int | None = None,
        status: WalletAdminRechargeStatus | None = None,
        created_from: datetime | None = None,
        created_to: datetime | None = None,
        search: str | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[WalletAdminRecharge], int]:
        """
        List recharge records, newest first, with pagination.

        Returns (items, total). The search filter matches wallet
        number, user full name, username, or phone via a join with
        the users table (fields that actually exist on User).
        """
        conditions = self._list_filters(
            wallet_number=wallet_number,
            user_id=user_id,
            admin_id=admin_id,
            status=status,
            created_from=created_from,
            created_to=created_to,
            search=search,
        )

        count_query = (
            select(func.count())
            .select_from(WalletAdminRecharge)
            .join(
                User,
                WalletAdminRecharge.user_id == User.id,
            )
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        query = (
            select(WalletAdminRecharge)
            .join(
                User,
                WalletAdminRecharge.user_id == User.id,
            )
            .where(*conditions)
            .order_by(WalletAdminRecharge.created_at.desc())
            .offset(offset)
            .limit(limit)
            .options(
                selectinload(WalletAdminRecharge.user),
                selectinload(WalletAdminRecharge.admin),
            )
        )

        result = await self.session.execute(query)

        return list(result.scalars().all()), total

    async def list_user_recharges(
        self,
        user_id: UUID | str,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[WalletAdminRecharge], int]:
        """List all recharge records for one user, newest first."""
        return await self.list_recharges(
            user_id=user_id,
            offset=offset,
            limit=limit,
        )

    # ============================================================
    # Statistics
    # ============================================================

    async def get_recharge_stats(
        self,
        *,
        created_from: datetime | None = None,
        created_to: datetime | None = None,
    ) -> dict:
        """
        Aggregate recharge statistics.

        Returns:
            total_operations: number of recharge records.
            total_coins_recharged: sum of amounts (CONFIRMED only).
            confirmed_count: number of CONFIRMED operations.
            failed_count: number of FAILED operations.

        All aggregates are computed in SQL over the actual rows;
        no business logic lives here.
        """
        conditions = []

        if created_from is not None:
            conditions.append(
                WalletAdminRecharge.created_at >= created_from,
            )

        if created_to is not None:
            conditions.append(
                WalletAdminRecharge.created_at <= created_to,
            )

        def _filtered(query):
            if conditions:
                return query.where(*conditions)
            return query

        total_operations = (
            await self.session.execute(
                _filtered(
                    select(func.count())
                    .select_from(WalletAdminRecharge)
                )
            )
        ).scalar_one()

        total_coins = (
            await self.session.execute(
                _filtered(
                    select(func.coalesce(func.sum(
                        WalletAdminRecharge.amount,
                    ), 0))
                    .select_from(WalletAdminRecharge)
                    .where(
                        WalletAdminRecharge.status
                        == WalletAdminRechargeStatus.CONFIRMED,
                    )
                )
            )
        ).scalar_one()

        confirmed_count = (
            await self.session.execute(
                _filtered(
                    select(func.count())
                    .select_from(WalletAdminRecharge)
                    .where(
                        WalletAdminRecharge.status
                        == WalletAdminRechargeStatus.CONFIRMED,
                    )
                )
            )
        ).scalar_one()

        failed_count = (
            await self.session.execute(
                _filtered(
                    select(func.count())
                    .select_from(WalletAdminRecharge)
                    .where(
                        WalletAdminRecharge.status
                        == WalletAdminRechargeStatus.FAILED,
                    )
                )
            )
        ).scalar_one()

        return {
            "total_operations": total_operations,
            "total_coins_recharged": int(total_coins),
            "confirmed_count": confirmed_count,
            "failed_count": failed_count,
        }

