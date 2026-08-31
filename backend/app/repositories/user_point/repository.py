"""Repository for user points and point transactions."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.user_point_transaction import (
    UserPointTransaction,
    UserPointTransactionStatus,
    UserPointTransactionType,
)


class UserPointRepository:
    def __init__(
        self,
        session: AsyncSession,
    ):
        self.session = session

    # ============================================================
    # User
    # ============================================================

    async def get_user(
        self,
        user_id: UUID | str,
        *,
        for_update: bool = False,
    ) -> User | None:
        """
        Get a user by ID.

        for_update=True locks the user row until the current
        database transaction is committed or rolled back.

        This is required when changing the user's points balance
        to prevent concurrent operations from overwriting each
        other's balance.
        """

        query = select(User).where(
            User.id == user_id,
        )

        if for_update:
            query = query.with_for_update()

        result = await self.session.execute(query)

        return result.scalar_one_or_none()

    # ============================================================
    # Point transactions
    # ============================================================

    async def create_transaction(
        self,
        transaction: UserPointTransaction,
    ) -> UserPointTransaction:
        """
        Add a point transaction to the current database transaction.

        This method intentionally does NOT commit.
        The service layer owns the transaction.
        """

        self.session.add(transaction)

        await self.session.flush()

        return transaction

    async def get_transaction_by_id(
        self,
        transaction_id: UUID | str,
    ) -> UserPointTransaction | None:
        result = await self.session.execute(
            select(UserPointTransaction).where(
                UserPointTransaction.id == transaction_id,
            )
        )

        return result.scalar_one_or_none()

    async def list_transactions(
        self,
        user_id: UUID | str,
        *,
        limit: int = 50,
        offset: int = 0,
        transaction_type: (
            UserPointTransactionType | None
        ) = None,
        status: (
            UserPointTransactionStatus | None
        ) = None,
    ) -> list[UserPointTransaction]:
        """
        List a user's point transaction history.
        """

        query = select(
            UserPointTransaction
        ).where(
            UserPointTransaction.user_id == user_id,
        )

        if transaction_type is not None:
            query = query.where(
                UserPointTransaction.type
                == transaction_type,
            )

        if status is not None:
            query = query.where(
                UserPointTransaction.status
                == status,
            )

        query = (
            query
            .order_by(
                UserPointTransaction.created_at.desc(),
            )
            .offset(offset)
            .limit(limit)
        )

        result = await self.session.execute(query)

        return list(
            result.scalars().all()
        )

    # ============================================================
    # Persistence
    # ============================================================

    async def flush(self) -> None:
        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()