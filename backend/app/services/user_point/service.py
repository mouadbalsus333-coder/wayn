"""Business logic for user points."""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_point_transaction import (
    UserPointTransaction,
    UserPointTransactionStatus,
    UserPointTransactionType,
)
from app.repositories.user_point.repository import (
    UserPointRepository,
)


class UserPointService:
    """
    Business logic for user points.

    User points are stored directly on User.points.

    Every balance mutation creates an immutable
    UserPointTransaction ledger entry.

    The user row is locked with SELECT ... FOR UPDATE
    before changing the balance so concurrent updates
    cannot overwrite each other's balance.
    """

    def __init__(
        self,
        session: AsyncSession,
    ) -> None:
        self.repository = UserPointRepository(session)

    # ============================================================
    # Balance
    # ============================================================

    async def get_balance(
        self,
        user_id: UUID | str,
    ) -> int:
        user = await self.repository.get_user(
            user_id,
        )

        if user is None:
            raise ValueError("User not found")

        return user.points

    # ============================================================
    # Transactions
    # ============================================================

    async def list_transactions(
        self,
        user_id: UUID | str,
        *,
        limit: int = 50,
        offset: int = 0,
        transaction_type: UserPointTransactionType | None = None,
        status: UserPointTransactionStatus | None = None,
    ) -> list[UserPointTransaction]:
        if limit < 1:
            raise ValueError(
                "Limit must be greater than zero",
            )

        if limit > 100:
            raise ValueError(
                "Limit cannot exceed 100",
            )

        if offset < 0:
            raise ValueError(
                "Offset cannot be negative",
            )

        user = await self.repository.get_user(
            user_id,
        )

        if user is None:
            raise ValueError("User not found")

        return await self.repository.list_transactions(
            user_id,
            limit=limit,
            offset=offset,
            transaction_type=transaction_type,
            status=status,
        )

    # ============================================================
    # Internal mutation
    # ============================================================

    async def _change_points(
        self,
        user_id: UUID | str,
        *,
        amount: int,
        transaction_type: UserPointTransactionType,
        description: str | None = None,
        reference_type: str | None = None,
        reference_id: UUID | str | None = None,
        admin_id: int | UUID | str | None = None,
        extra_data: dict | None = None,
    ) -> UserPointTransaction:
        """
        Change a user's points balance and create the
        corresponding immutable ledger entry.

        The user row is locked with SELECT ... FOR UPDATE
        so concurrent balance changes cannot overwrite
        each other's balance.

        The caller does not need to manage the transaction.
        This method commits the balance mutation and its
        ledger entry together.
        """

        if amount == 0:
            raise ValueError(
                "Points amount cannot be zero",
            )

        user = await self.repository.get_user(
            user_id,
            for_update=True,
        )

        if user is None:
            raise ValueError("User not found")

        # --------------------------------------------------------
        # Calculate new balance
        # --------------------------------------------------------

        current_balance = user.points

        new_balance = current_balance + amount

        if new_balance < 0:
            raise ValueError(
                "Insufficient points balance",
            )

        # --------------------------------------------------------
        # Update user balance
        # --------------------------------------------------------

        user.points = new_balance

        # --------------------------------------------------------
        # Prepare transaction metadata
        # --------------------------------------------------------

        transaction_data = dict(
            extra_data or {},
        )

        if admin_id is not None:
            transaction_data["admin_id"] = str(
                admin_id,
            )
            transaction_data["source"] = "ADMIN"

        # --------------------------------------------------------
        # Normalize reference ID
        # --------------------------------------------------------

        normalized_reference_id: UUID | None = None

        if reference_id is not None:
            try:
                normalized_reference_id = UUID(
                    str(reference_id),
                )
            except (TypeError, ValueError) as exc:
                raise ValueError(
                    "Invalid reference_id",
                ) from exc

        # --------------------------------------------------------
        # Create immutable ledger record
        # --------------------------------------------------------

        transaction = UserPointTransaction(
            user_id=user.id,
            type=transaction_type,
            status=(
                UserPointTransactionStatus.CONFIRMED
            ),
            amount=amount,
            balance_after=new_balance,
            description=description,
            reference_type=reference_type,
            reference_id=normalized_reference_id,
            extra_data=transaction_data,
        )

        try:
            await self.repository.create_transaction(
                transaction,
            )

            await self.repository.commit()

        except Exception:
            await self.repository.rollback()
            raise

        return transaction

    # ============================================================
    # Add points
    # ============================================================

    async def add_points(
        self,
        user_id: UUID | str,
        amount: int,
        *,
        transaction_type: UserPointTransactionType = (
            UserPointTransactionType.ADJUSTMENT
        ),
        description: str | None = None,
        reference_type: str | None = None,
        reference_id: UUID | str | None = None,
        admin_id: int | UUID | str | None = None,
        extra_data: dict | None = None,
    ) -> UserPointTransaction:
        """
        Add points to a user.

        Example:
            +100 points
        """

        if amount <= 0:
            raise ValueError(
                "Points amount must be greater than zero",
            )

        return await self._change_points(
            user_id,
            amount=amount,
            transaction_type=transaction_type,
            description=description,
            reference_type=reference_type,
            reference_id=reference_id,
            admin_id=admin_id,
            extra_data=extra_data,
        )

    # ============================================================
    # Remove points
    # ============================================================

    async def remove_points(
        self,
        user_id: UUID | str,
        amount: int,
        *,
        transaction_type: UserPointTransactionType = (
            UserPointTransactionType.ADJUSTMENT
        ),
        description: str | None = None,
        reference_type: str | None = None,
        reference_id: UUID | str | None = None,
        admin_id: int | UUID | str | None = None,
        extra_data: dict | None = None,
    ) -> UserPointTransaction:
        """
        Remove points from a user.

        Example:
            -50 points
        """

        if amount <= 0:
            raise ValueError(
                "Points amount must be greater than zero",
            )

        return await self._change_points(
            user_id,
            amount=-amount,
            transaction_type=transaction_type,
            description=description,
            reference_type=reference_type,
            reference_id=reference_id,
            admin_id=admin_id,
            extra_data=extra_data,
        )