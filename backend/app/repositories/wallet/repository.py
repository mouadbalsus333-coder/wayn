"""Repository for user wallets, wallet transactions, and wallet transfers."""

from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.wallet import UserWallet, WalletStatus
from app.models.wallet_transaction import (
    WalletTransaction,
    WalletTransactionStatus,
)
from app.models.wallet_transfer import WalletTransfer


class WalletRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # ============================================================
    # Wallet
    # ============================================================

    async def get_wallet_by_user_id(
        self,
        user_id: UUID | str,
        *,
        for_update: bool = False,
    ) -> UserWallet | None:
        query = select(UserWallet).where(
            UserWallet.user_id == user_id
        )

        if for_update:
            query = query.with_for_update()

        result = await self.session.execute(query)

        return result.scalar_one_or_none()

    async def get_wallet_by_id(
        self,
        wallet_id: UUID | str,
        *,
        for_update: bool = False,
    ) -> UserWallet | None:
        query = select(UserWallet).where(
            UserWallet.id == wallet_id
        )

        if for_update:
            query = query.with_for_update()

        result = await self.session.execute(query)

        return result.scalar_one_or_none()

    async def get_wallet_by_number(
        self,
        wallet_number: str,
        *,
        for_update: bool = False,
    ) -> UserWallet | None:
        query = select(UserWallet).where(
            UserWallet.wallet_number == wallet_number
        )

        if for_update:
            query = query.with_for_update()

        result = await self.session.execute(query)

        return result.scalar_one_or_none()

    async def get_wallets_for_transfer(
        self,
        sender_wallet_id: UUID,
        receiver_wallet_id: UUID,
    ) -> tuple[UserWallet | None, UserWallet | None]:
        """
        Lock both wallets using deterministic UUID ordering.

        This prevents lock-order deadlocks when two transfers
        happen concurrently in opposite directions:

            A -> B
            B -> A

        Both transactions acquire the wallet locks in the same
        deterministic order.

        populate_existing=True ensures that SQLAlchemy refreshes
        the ORM state from the database after waiting for a lock.
        """

        wallet_ids = sorted(
            [sender_wallet_id, receiver_wallet_id],
            key=str,
        )

        result = await self.session.execute(
            select(UserWallet)
            .where(UserWallet.id.in_(wallet_ids))
            .order_by(UserWallet.id)
            .with_for_update()
            .execution_options(
                populate_existing=True,
            )
        )

        wallets = {
            wallet.id: wallet
            for wallet in result.scalars().all()
        }

        return (
            wallets.get(sender_wallet_id),
            wallets.get(receiver_wallet_id),
        )

    async def create_wallet(
        self,
        wallet: UserWallet,
    ) -> UserWallet:
        self.session.add(wallet)

        await self.session.flush()
        await self.session.refresh(wallet)

        return wallet

    # ============================================================
    # Wallet status / protection
    # ============================================================

    async def update_wallet_status(
        self,
        wallet: UserWallet,
        *,
        status: WalletStatus,
        reason: str | None = None,
        changed_by: int | None = None,
        suspended_until: datetime | None = None,
    ) -> UserWallet:
        """
        Update wallet account status.

        The caller is responsible for acquiring the wallet row
        lock when this operation participates in a concurrent
        business transaction.
        """

        wallet.status = status
        wallet.status_reason = reason
        wallet.status_changed_at = datetime.now(timezone.utc)
        wallet.status_changed_by = changed_by

        if status == WalletStatus.SUSPENDED:
            wallet.suspended_until = suspended_until
        else:
            wallet.suspended_until = None

        await self.session.flush()
        await self.session.refresh(wallet)

        return wallet

    async def block_transfers(
        self,
        wallet: UserWallet,
        *,
        blocked_until: datetime | None = None,
        reason: str | None = None,
    ) -> UserWallet:
        """
        Block outgoing transfers from a wallet.

        blocked_until=None means the block remains active until
        explicitly removed.
        """

        wallet.transfers_blocked_until = blocked_until
        wallet.transfers_block_reason = reason

        await self.session.flush()
        await self.session.refresh(wallet)

        return wallet

    async def unblock_transfers(
        self,
        wallet: UserWallet,
    ) -> UserWallet:
        """Remove the wallet's outgoing transfer block."""

        wallet.transfers_blocked_until = None
        wallet.transfers_block_reason = None

        await self.session.flush()
        await self.session.refresh(wallet)

        return wallet

    # ============================================================
    # Wallet Transactions
    # ============================================================

    async def create_transaction(
        self,
        transaction: WalletTransaction,
    ) -> WalletTransaction:
        self.session.add(transaction)

        await self.session.flush()
        await self.session.refresh(transaction)

        return transaction

    async def get_transaction_by_id(
        self,
        transaction_id: UUID | str,
    ) -> WalletTransaction | None:
        result = await self.session.execute(
            select(WalletTransaction).where(
                WalletTransaction.id == transaction_id
            )
        )

        return result.scalar_one_or_none()

    async def list_transactions(
        self,
        wallet_id: UUID | str,
        *,
        limit: int = 50,
        offset: int = 0,
        status: WalletTransactionStatus | None = None,
    ) -> list[WalletTransaction]:
        query = select(WalletTransaction).where(
            WalletTransaction.wallet_id == wallet_id
        )

        if status is not None:
            query = query.where(
                WalletTransaction.status == status
            )

        query = (
            query
            .order_by(WalletTransaction.created_at.desc())
            .offset(offset)
            .limit(limit)
        )

        result = await self.session.execute(query)

        return list(result.scalars().all())

    # ============================================================
    # Wallet Transfers
    # ============================================================

    async def create_transfer(
        self,
        transfer: WalletTransfer,
    ) -> WalletTransfer:
        self.session.add(transfer)

        await self.session.flush()
        await self.session.refresh(transfer)

        return transfer

    async def get_transfer_by_idempotency_key(
        self,
        sender_wallet_id: UUID,
        idempotency_key: str,
        *,
        for_update: bool = False,
    ) -> WalletTransfer | None:
        """
        Find a transfer using the sender wallet and idempotency key.

        The database unique constraint/index remains the final
        protection against duplicate idempotency keys.

        for_update can be enabled when the caller needs to lock
        the existing transfer row as part of a larger transaction.
        """

        query = select(WalletTransfer).where(
            WalletTransfer.sender_wallet_id == sender_wallet_id,
            WalletTransfer.idempotency_key == idempotency_key,
        )

        if for_update:
            query = query.with_for_update()

        result = await self.session.execute(query)

        return result.scalar_one_or_none()

    async def get_transfer_by_id(
        self,
        transfer_id: UUID | str,
        *,
        for_update: bool = False,
    ) -> WalletTransfer | None:
        query = select(WalletTransfer).where(
            WalletTransfer.id == transfer_id
        )

        if for_update:
            query = query.with_for_update()

        result = await self.session.execute(query)

        return result.scalar_one_or_none()

    # ============================================================
    # Transaction persistence
    # ============================================================

    async def flush(self) -> None:
        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()
