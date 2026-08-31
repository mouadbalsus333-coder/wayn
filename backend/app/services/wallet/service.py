"""Business logic for user wallets, coins, and user points."""

from datetime import datetime, timezone
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.wallet import UserWallet, WalletStatus
from app.models.wallet_transaction import (
    WalletAsset,
    WalletTransaction,
    WalletTransactionStatus,
    WalletTransactionType,
)
from app.models.wallet_transfer import (
    WalletTransfer,
    WalletTransferStatus,
)
from app.repositories.wallet.repository import WalletRepository


class WalletService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = WalletRepository(session)

    # ============================================================
    # Wallet
    # ============================================================

    async def get_wallet(
        self,
        user_id: UUID | str,
    ) -> UserWallet | None:
        return await self.repository.get_wallet_by_user_id(
            user_id
        )

    async def get_or_create_wallet(
        self,
        user_id: UUID | str,
    ) -> UserWallet:
        wallet = await self.repository.get_wallet_by_user_id(
            user_id
        )

        if wallet is not None:
            return wallet

        wallet = UserWallet(
            user_id=user_id,
            coins_balance=0,
        )

        try:
            await self.repository.create_wallet(wallet)
            await self.repository.commit()

        except Exception:
            await self.repository.rollback()

            existing_wallet = (
                await self.repository.get_wallet_by_user_id(
                    user_id
                )
            )

            if existing_wallet is not None:
                return existing_wallet

            raise

        return wallet

    # ============================================================
    # Wallet protection
    # ============================================================

    @staticmethod
    def _validate_wallet_active(
        wallet: UserWallet,
        *,
        operation: str = "use",
    ) -> None:
        """
        Validate the general operational state of a wallet.

        ACTIVE wallets are allowed.

        SUSPENDED wallets are rejected.

        HIDDEN wallets are rejected.

        Any unknown/non-active status is rejected.
        """

        if wallet.status == WalletStatus.SUSPENDED:
            if wallet.suspended_until is not None:
                now = datetime.now(timezone.utc)

                if now < wallet.suspended_until:
                    raise ValueError(
                        "Wallet is suspended"
                    )

                raise ValueError(
                    "Wallet suspension has expired but "
                    "the wallet is still suspended"
                )

            raise ValueError(
                "Wallet is suspended"
            )

        if wallet.status == WalletStatus.HIDDEN:
            raise ValueError(
                "Wallet is hidden"
            )

        if wallet.status != WalletStatus.ACTIVE:
            raise ValueError(
                "Wallet is not active"
            )

    @classmethod
    def _validate_wallet_transfer_access(
        cls,
        wallet: UserWallet,
    ) -> None:
        """
        Validate whether a wallet is allowed to send transfers.

        The wallet must:
        - be ACTIVE
        - not be suspended
        - not be hidden
        - not currently have transfers blocked
        """

        cls._validate_wallet_active(
            wallet,
            operation="transfer",
        )

        if wallet.transfers_block_reason is not None:
            if wallet.transfers_blocked_until is not None:
                now = datetime.now(timezone.utc)

                if now < wallet.transfers_blocked_until:
                    raise ValueError(
                        "Wallet transfers are temporarily blocked"
                    )

                # The block has expired.
                #
                # We intentionally do not clear the database
                # fields here because they are useful as
                # historical protection metadata.

            else:
                # No expiry timestamp means the block is permanent
                # until explicitly removed.
                raise ValueError(
                    "Wallet transfers are temporarily blocked"
                )

    # ============================================================
    # User points
    # ============================================================

    async def get_points_balance(
        self,
        user_id: UUID | str,
    ) -> int:
        """
        Return the user's points.

        Points are stored directly on users.points and are
        intentionally independent from the wallet.
        """

        result = await self.session.execute(
            sa.select(User.points).where(
                User.id == user_id
            )
        )

        points = result.scalar_one_or_none()

        if points is None:
            return 0

        return int(points)

    async def _change_points(
        self,
        user_id: UUID | str,
        *,
        amount: int,
        description: str | None = None,
        reference_type: str | None = None,
        reference_id: UUID | None = None,
        extra_data: dict | None = None,
    ) -> int:
        """
        Change a user's points balance.

        Points are NOT wallet assets.

        The user row is locked with FOR UPDATE so concurrent
        point changes cannot overwrite each other.

        The resulting points balance is returned.
        """

        if amount == 0:
            raise ValueError(
                "Points amount cannot be zero"
            )

        result = await self.session.execute(
            sa.select(User)
            .where(User.id == user_id)
            .with_for_update()
        )

        user = result.scalar_one_or_none()

        if user is None:
            raise ValueError(
                "User not found"
            )

        # Points cannot become negative.
        new_balance = user.points + amount

        if new_balance < 0:
            raise ValueError(
                "Insufficient points balance"
            )

        user.points = new_balance

        try:
            await self.session.commit()

        except Exception:
            await self.session.rollback()
            raise

        return int(new_balance)

    async def add_points(
        self,
        user_id: UUID | str,
        amount: int,
        *,
        description: str | None = None,
        reference_type: str | None = None,
        reference_id: UUID | None = None,
        extra_data: dict | None = None,
    ) -> int:
        """
        Add points directly to the user.

        Intended for controlled internal operations such as:
        - admin rewards
        - moderation rewards
        - user contributions
        - campaigns
        - system rewards
        """

        if amount <= 0:
            raise ValueError(
                "Points amount must be greater than zero"
            )

        return await self._change_points(
            user_id,
            amount=amount,
            description=description,
            reference_type=reference_type,
            reference_id=reference_id,
            extra_data=extra_data,
        )

    async def remove_points(
        self,
        user_id: UUID | str,
        amount: int,
        *,
        description: str | None = None,
        reference_type: str | None = None,
        reference_id: UUID | None = None,
        extra_data: dict | None = None,
    ) -> int:
        """
        Remove points directly from the user.

        The balance can never become negative.
        """

        if amount <= 0:
            raise ValueError(
                "Points amount must be greater than zero"
            )

        return await self._change_points(
            user_id,
            amount=-amount,
            description=description,
            reference_type=reference_type,
            reference_id=reference_id,
            extra_data=extra_data,
        )

    # ============================================================
    # Coins balance
    # ============================================================

    async def get_coins_balance(
        self,
        user_id: UUID | str,
    ) -> int:
        wallet = await self.repository.get_wallet_by_user_id(
            user_id
        )

        if wallet is None:
            return 0

        return wallet.coins_balance

    # ============================================================
    # Transactions
    # ============================================================

    async def list_transactions(
        self,
        user_id: UUID | str,
        *,
        limit: int = 50,
        offset: int = 0,
        status: WalletTransactionStatus | None = None,
    ) -> list[WalletTransaction]:
        """
        List wallet transactions.

        Wallet transactions currently represent wallet assets,
        which means Coins. User Points are stored separately
        on users.points.
        """

        if limit < 1:
            raise ValueError(
                "Limit must be greater than zero"
            )

        if limit > 100:
            raise ValueError(
                "Limit cannot exceed 100"
            )

        if offset < 0:
            raise ValueError(
                "Offset cannot be negative"
            )

        wallet = await self.repository.get_wallet_by_user_id(
            user_id
        )

        if wallet is None:
            return []

        return await self.repository.list_transactions(
            wallet.id,
            limit=limit,
            offset=offset,
            status=status,
        )

    # ============================================================
    # Internal coins balance mutation
    # ============================================================

    async def _change_coins(
        self,
        user_id: UUID | str,
        *,
        amount: int,
        transaction_type: WalletTransactionType,
        description: str | None = None,
        reference_type: str | None = None,
        reference_id: UUID | None = None,
        extra_data: dict | None = None,
    ) -> WalletTransaction:
        """
        Change a user's Coins balance.

        Coins belong to UserWallet.

        Points intentionally do not use this method.
        """

        if amount == 0:
            raise ValueError(
                "Transaction amount cannot be zero"
            )

        wallet = await self.repository.get_wallet_by_user_id(
            user_id,
            for_update=True,
        )

        if wallet is None:
            raise ValueError(
                "Wallet not found"
            )

        self._validate_wallet_active(wallet)

        new_balance = wallet.coins_balance + amount

        if new_balance < 0:
            raise ValueError(
                "Insufficient coins balance"
            )

        wallet.coins_balance = new_balance

        transaction = WalletTransaction(
            wallet_id=wallet.id,
            asset=WalletAsset.COINS,
            type=transaction_type,
            status=WalletTransactionStatus.CONFIRMED,
            amount=amount,
            description=description,
            reference_type=reference_type,
            reference_id=reference_id,
            extra_data=extra_data or {},
        )

        try:
            await self.repository.create_transaction(
                transaction
            )

            await self.repository.commit()

        except Exception:
            await self.repository.rollback()
            raise

        return transaction

    # ============================================================
    # Transfers
    # ============================================================

    async def transfer(
        self,
        sender_user_id: UUID | str,
        receiver_wallet_number: str,
        *,
        asset: WalletAsset,
        amount: int,
        description: str | None = None,
        extra_data: dict | None = None,
        idempotency_key: str | None = None,
    ) -> WalletTransfer:
        """
        Transfer Coins between two wallets.

        Points cannot be transferred through the wallet system.

        Guarantees:
        - Positive transfer amount.
        - Coins only.
        - Sender must own an active wallet.
        - Sender transfers can be temporarily blocked.
        - Receiver must have an active wallet.
        - Self-transfer is rejected.
        - Both wallets are locked in deterministic UUID order.
        - Balance changes and ledger entries are atomic.
        - Idempotency keys prevent duplicate transfers.
        - Repeated identical requests return the original transfer.
        - Reusing an idempotency key for a different operation
          is rejected.
        """

        # ========================================================
        # Basic validation
        # ========================================================

        if amount <= 0:
            raise ValueError(
                "Transfer amount must be greater than zero"
            )

        # Points are no longer wallet assets.
        if asset != WalletAsset.COINS:
            raise ValueError(
                "Only coins can be transferred between wallets"
            )

        receiver_wallet_number = (
            receiver_wallet_number.strip()
        )

        if not receiver_wallet_number:
            raise ValueError(
                "Receiver wallet number is required"
            )

        # ========================================================
        # Idempotency key validation
        # ========================================================

        if idempotency_key is not None:
            idempotency_key = idempotency_key.strip()

            if not idempotency_key:
                raise ValueError(
                    "Idempotency key cannot be empty"
                )

            if len(idempotency_key) > 100:
                raise ValueError(
                    "Idempotency key cannot exceed 100 characters"
                )

        # ========================================================
        # Lock sender wallet
        # ========================================================

        sender_wallet = (
            await self.repository.get_wallet_by_user_id(
                sender_user_id,
                for_update=True,
            )
        )

        if sender_wallet is None:
            raise ValueError(
                "Sender wallet not found"
            )

        # ========================================================
        # Idempotency lookup
        # ========================================================

        if idempotency_key is not None:
            existing_transfer = (
                await self.repository.get_transfer_by_idempotency_key(
                    sender_wallet.id,
                    idempotency_key,
                )
            )

            if existing_transfer is not None:

                if (
                    existing_transfer.asset != asset
                    or existing_transfer.amount != amount
                ):
                    raise ValueError(
                        "Idempotency key was already used "
                        "with different transfer parameters"
                    )

                receiver_wallet = (
                    await self.repository.get_wallet_by_number(
                        receiver_wallet_number
                    )
                )

                if receiver_wallet is None:
                    raise ValueError(
                        "Receiver wallet not found"
                    )

                if (
                    existing_transfer.receiver_wallet_id
                    != receiver_wallet.id
                ):
                    raise ValueError(
                        "Idempotency key was already used "
                        "with a different receiver wallet"
                    )

                if (
                    existing_transfer.description
                    != description
                ):
                    raise ValueError(
                        "Idempotency key was already used "
                        "with a different description"
                    )

                return existing_transfer

        # ========================================================
        # Validate sender transfer access
        # ========================================================

        self._validate_wallet_transfer_access(
            sender_wallet
        )

        # ========================================================
        # Find receiver wallet
        # ========================================================

        receiver_wallet = (
            await self.repository.get_wallet_by_number(
                receiver_wallet_number
            )
        )

        if receiver_wallet is None:
            raise ValueError(
                "Receiver wallet not found"
            )

        # ========================================================
        # Prevent self transfer
        # ========================================================

        if sender_wallet.id == receiver_wallet.id:
            raise ValueError(
                "Cannot transfer to the same wallet"
            )

        # ========================================================
        # Lock both wallets
        # ========================================================

        (
            sender_wallet,
            receiver_wallet,
        ) = await self.repository.get_wallets_for_transfer(
            sender_wallet.id,
            receiver_wallet.id,
        )

        if sender_wallet is None:
            raise ValueError(
                "Sender wallet not found"
            )

        if receiver_wallet is None:
            raise ValueError(
                "Receiver wallet not found"
            )

        # ========================================================
        # Revalidate sender after final locks
        # ========================================================

        self._validate_wallet_transfer_access(
            sender_wallet
        )

        # ========================================================
        # Validate receiver
        # ========================================================

        if receiver_wallet.status != WalletStatus.ACTIVE:
            raise ValueError(
                "Receiver wallet is not active"
            )

        # ========================================================
        # Validate Coins balance
        # ========================================================

        if sender_wallet.coins_balance < amount:
            raise ValueError(
                "Insufficient coins balance"
            )

        # ========================================================
        # Atomic transfer
        # ========================================================

        try:
            # ----------------------------------------------------
            # Update Coins balances
            # ----------------------------------------------------

            sender_wallet.coins_balance -= amount
            receiver_wallet.coins_balance += amount

            # ----------------------------------------------------
            # Create transfer record
            # ----------------------------------------------------

            transfer = WalletTransfer(
                sender_wallet_id=sender_wallet.id,
                receiver_wallet_id=receiver_wallet.id,
                asset=WalletAsset.COINS,
                amount=amount,
                status=WalletTransferStatus.PENDING,
                description=description,
                idempotency_key=idempotency_key,
            )

            await self.repository.create_transfer(
                transfer
            )

            # ----------------------------------------------------
            # Sender ledger entry
            # ----------------------------------------------------

            sender_transaction = WalletTransaction(
                wallet_id=sender_wallet.id,
                asset=WalletAsset.COINS,
                type=WalletTransactionType.TRANSFER,
                status=WalletTransactionStatus.CONFIRMED,
                amount=-amount,
                description=(
                    description
                    or "Wallet transfer sent"
                ),
                reference_type="wallet_transfer",
                reference_id=transfer.id,
                extra_data={
                    **(extra_data or {}),
                    "direction": "OUT",
                    "counterparty_wallet_id": str(
                        receiver_wallet.id
                    ),
                    "transfer_id": str(
                        transfer.id
                    ),
                },
            )

            await self.repository.create_transaction(
                sender_transaction
            )

            # ----------------------------------------------------
            # Receiver ledger entry
            # ----------------------------------------------------

            receiver_transaction = WalletTransaction(
                wallet_id=receiver_wallet.id,
                asset=WalletAsset.COINS,
                type=WalletTransactionType.TRANSFER,
                status=WalletTransactionStatus.CONFIRMED,
                amount=amount,
                description=(
                    description
                    or "Wallet transfer received"
                ),
                reference_type="wallet_transfer",
                reference_id=transfer.id,
                extra_data={
                    **(extra_data or {}),
                    "direction": "IN",
                    "counterparty_wallet_id": str(
                        sender_wallet.id
                    ),
                    "transfer_id": str(
                        transfer.id
                    ),
                },
            )

            await self.repository.create_transaction(
                receiver_transaction
            )

            # ----------------------------------------------------
            # Mark transfer as confirmed
            # ----------------------------------------------------

            transfer.status = (
                WalletTransferStatus.CONFIRMED
            )

            transfer.completed_at = datetime.now(
                timezone.utc
            )

            # ----------------------------------------------------
            # Flush all changes
            # ----------------------------------------------------

            await self.repository.flush()

            # ----------------------------------------------------
            # Single atomic commit
            # ----------------------------------------------------

            await self.repository.commit()

            return transfer

        except Exception:
            await self.repository.rollback()
            raise

    # ============================================================
    # Coins
    # ============================================================

    async def add_coins(
        self,
        user_id: UUID | str,
        amount: int,
        *,
        transaction_type: WalletTransactionType,
        description: str | None = None,
        reference_type: str | None = None,
        reference_id: UUID | None = None,
        extra_data: dict | None = None,
    ) -> WalletTransaction:
        """
        Add Coins to the user's wallet.

        This is suitable for controlled internal operations,
        including administrator adjustments.
        """

        if amount <= 0:
            raise ValueError(
                "Coins amount must be greater than zero"
            )

        return await self._change_coins(
            user_id,
            amount=amount,
            transaction_type=transaction_type,
            description=description,
            reference_type=reference_type,
            reference_id=reference_id,
            extra_data=extra_data,
        )

    async def remove_coins(
        self,
        user_id: UUID | str,
        amount: int,
        *,
        transaction_type: WalletTransactionType,
        description: str | None = None,
        reference_type: str | None = None,
        reference_id: UUID | None = None,
        extra_data: dict | None = None,
    ) -> WalletTransaction:
        """
        Remove Coins from the user's wallet.

        The balance can never become negative.
        """

        if amount <= 0:
            raise ValueError(
                "Coins amount must be greater than zero"
            )

        return await self._change_coins(
            user_id,
            amount=-amount,
            transaction_type=transaction_type,
            description=description,
            reference_type=reference_type,
            reference_id=reference_id,
            extra_data=extra_data,
        )
