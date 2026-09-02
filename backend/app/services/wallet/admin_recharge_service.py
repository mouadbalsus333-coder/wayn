"""Business logic for admin wallet recharges (COINS only)."""

from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select as sa_select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.social import UserNotification
from app.models.user import User
from app.models.wallet import UserWallet, WalletStatus
from app.models.wallet_admin_recharge import (
    WalletAdminRecharge,
    WalletAdminRechargeStatus,
)
from app.models.wallet_transaction import (
    WalletAsset,
    WalletTransaction,
    WalletTransactionStatus,
    WalletTransactionType,
)
from app.repositories.wallet.admin_recharge_repository import (
    AdminRechargeRepository,
)
from app.repositories.wallet.repository import WalletRepository


# PostgreSQL BigInteger upper bound (coins_balance is BigInteger).
_MAX_BIGINT = 9223372036854775807

# The unique index that is the final idempotency protection.
_IDEMPOTENCY_CONSTRAINT = (
    "uq_wallet_admin_recharges_admin_idempotency"
)


def _is_idempotency_violation(exc: IntegrityError) -> bool:
    """
    True only when the IntegrityError was caused by the idempotency
    unique index.

    asyncpg exposes the violated constraint on the original DBAPI
    exception as ``constraint_name``; psycopg-style drivers expose it
    via ``orig.diag.constraint_name``. Both are checked without
    adding any dependency. Any other constraint (or an unknown one)
    returns False so the error is re-raised instead of being
    silently treated as a duplicate request.
    """
    orig = exc.orig

    constraint = getattr(orig, "constraint_name", None)

    if constraint is None:
        diag = getattr(orig, "diag", None)

        if diag is not None:
            constraint = getattr(
                diag,
                "constraint_name",
                None,
            )

    return constraint == _IDEMPOTENCY_CONSTRAINT



class AdminRechargeService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = AdminRechargeRepository(session)
        self.wallet_repository = WalletRepository(session)

    # ============================================================
    # Lookup (read-only, no balance changes)
    # ============================================================

    async def lookup_wallet(
        self,
        *,
        wallet_number: str | None = None,
        user_id: UUID | str | None = None,
    ) -> dict | None:
        """
        Find a wallet + its owner for the confirmation screen.

        Exactly one of wallet_number / user_id must be provided.
        Returns None when no account matches.
        """
        if (wallet_number is None) == (user_id is None):
            raise ValueError(
                "Provide exactly one of wallet_number or user_id"
            )

        if wallet_number is not None:
            wallet_number = wallet_number.strip()

            if not wallet_number:
                raise ValueError(
                    "Wallet number is required"
                )

            found = await self.repository.find_wallet_by_number(
                wallet_number,
            )
        else:
            found = await self.repository.find_wallet_by_user_id(
                user_id,
            )

        if found is None:
            return None

        wallet, user = found

        return {
            "user_id": user.id,
            "wallet_id": wallet.id,
            "wallet_number": wallet.wallet_number,
            "full_name": user.full_name,
            "username": user.username,
            "phone": user.phone,
            "coins_balance": wallet.coins_balance,
            "wallet_status": wallet.status,
            "is_active": user.is_active,
            "is_verified": user.is_verified,
        }

    # ============================================================
    # Validation helpers
    # ============================================================

    @staticmethod
    def _validate_amount(amount: int) -> None:
        if not isinstance(amount, int) or isinstance(amount, bool):
            raise ValueError(
                "Recharge amount must be an integer"
            )

        if amount <= 0:
            raise ValueError(
                "Recharge amount must be greater than zero"
            )

    @staticmethod
    def _validate_wallet_active(
        wallet: UserWallet,
    ) -> None:
        """Admin recharges are only allowed on ACTIVE wallets."""
        if wallet.status == WalletStatus.SUSPENDED:
            raise ValueError("Wallet is suspended")

        if wallet.status == WalletStatus.HIDDEN:
            raise ValueError("Wallet is hidden")

        if wallet.status != WalletStatus.ACTIVE:
            raise ValueError("Wallet is not active")

    @staticmethod
    def _validate_idempotency_key(
        idempotency_key: str | None,
    ) -> str | None:
        if idempotency_key is None:
            return None

        idempotency_key = idempotency_key.strip()

        if not idempotency_key:
            raise ValueError(
                "Idempotency key cannot be empty"
            )

        if len(idempotency_key) > 100:
            raise ValueError(
                "Idempotency key cannot exceed 100 characters"
            )

        return idempotency_key

    # ============================================================
    # Internal builders (inside the recharge transaction)
    # ============================================================

    @staticmethod
    def _build_transaction(
        *,
        wallet: UserWallet,
        amount: int,
        description: str,
    ) -> WalletTransaction:
        return WalletTransaction(
            wallet_id=wallet.id,
            asset=WalletAsset.COINS,
            type=WalletTransactionType.ADMIN_RECHARGE,
            status=WalletTransactionStatus.CONFIRMED,
            amount=amount,
            description=description,
            reference_type="wallet_admin_recharge",
            # reference_id is set after the recharge row is flushed
            # (see recharge_wallet) because the recharge primary key
            # is generated by the database.
            reference_id=None,
            extra_data={},
        )

    @staticmethod
    def _build_recharge(
        *,
        wallet: UserWallet,
        user: User,
        transaction_id: UUID,
        amount: int,
        balance_before: int,
        balance_after: int,
        admin_id: int,
        admin_email: str,
        note: str | None,
        idempotency_key: str | None,
        ip_address: str | None,
        user_agent: str | None,
    ) -> WalletAdminRecharge:
        return WalletAdminRecharge(
            transaction_id=transaction_id,
            wallet_id=wallet.id,
            user_id=user.id,
            wallet_number=wallet.wallet_number,
            amount=amount,
            balance_before=balance_before,
            balance_after=balance_after,
            admin_id=admin_id,
            admin_email=admin_email,
            note=note,
            status=WalletAdminRechargeStatus.CONFIRMED,
            idempotency_key=idempotency_key,
            ip_address=ip_address,
            user_agent=user_agent,
        )

    @staticmethod
    def _build_notification(
        *,
        user_id: UUID,
        amount: int,
        balance_after: int,
        transaction_id: UUID,
        recharge_id: UUID,
    ) -> UserNotification:
        return UserNotification(
            user_id=user_id,
            actor_user_id=None,
            type="WALLET_ADMIN_RECHARGE",
            text=(
                f"تم شحن محفظتك 🎉 تمت إضافة "
                f"{amount:,} عملة إلى محفظتك من الإدارة."
            ),
            data={
                "amount": amount,
                "balance_after": balance_after,
                "transaction_id": str(transaction_id),
                "recharge_id": str(recharge_id),
                "operation_type": "ADMIN_RECHARGE",
                "occurred_at": datetime.now(timezone.utc).isoformat(),
            },
        )

    # ============================================================
    # Recharge (atomic financial operation)
    # ============================================================

    async def recharge_wallet(
        self,
        *,
        target_user_id: UUID | str,
        amount: int,
        admin: object,
        note: str | None = None,
        idempotency_key: str | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
    ) -> WalletAdminRecharge:
        """
        Recharge a user's wallet with Coins.

        Atomic guarantees (single database transaction):
        - wallet balance update (locked with FOR UPDATE)
        - WalletTransaction ledger entry (ADMIN_RECHARGE)
        - WalletAdminRecharge audit record
        - UserNotification for the target user

        Any failure rolls the whole operation back.

        Idempotency:
        - (admin_id, idempotency_key) is checked first; an existing
          record is returned without recharging.
        - The unique index
          uq_wallet_admin_recharges_admin_idempotency is the final
          protection: an IntegrityError caused by a concurrent
          duplicate rolls back, re-reads the existing record, and
          returns it. Other IntegrityErrors are re-raised.
        """
        # --------------------------------------------------------
        # Validation (backend-side only, no DB access)
        # --------------------------------------------------------

        self._validate_amount(amount)

        idempotency_key = self._validate_idempotency_key(
            idempotency_key,
        )

        if note is not None:
            note = note.strip()

            if not note:
                note = None

        admin_id = int(admin.id)
        admin_email = admin.email

        # --------------------------------------------------------
        # Everything below runs inside ONE transaction boundary.
        #
        # Any failure (validation after lock, missing user, overflow,
        # database error, ...) rolls the session back, matching the
        # WalletService try/commit + except/rollback pattern.
        # --------------------------------------------------------

        try:
            # ----------------------------------------------------
            # Idempotency pre-check (read-only)
            # ----------------------------------------------------

            if idempotency_key is not None:
                existing = (
                    await
                    self.repository.get_recharge_by_idempotency_key(
                        admin_id,
                        idempotency_key,
                    )
                )

                if existing is not None:
                    return existing

            # ----------------------------------------------------
            # Lock the target wallet (race-condition protection)
            # ----------------------------------------------------

            wallet = (
                await self.wallet_repository.get_wallet_by_user_id(
                    target_user_id,
                    for_update=True,
                )
            )

            if wallet is None:
                raise ValueError("User wallet not found")

            self._validate_wallet_active(wallet)

            # Fetch the owner explicitly: wallet.user is a lazy
            # relationship and lazy loading fails inside AsyncSession
            # (MissingGreenlet). The lookup method uses a tuple select
            # for the same reason.
            user_result = await self.session.execute(
                sa_select(User).where(User.id == wallet.user_id)
            )

            user = user_result.scalar_one_or_none()

            if user is None:
                raise ValueError("User not found")

            # ----------------------------------------------------
            # Balances are computed here only (never by the client)
            # ----------------------------------------------------

            balance_before = int(wallet.coins_balance)

            balance_after = balance_before + amount

            if balance_after > _MAX_BIGINT:
                raise ValueError(
                    "Recharge would exceed the maximum wallet balance"
                )

            # ----------------------------------------------------
            # Atomic mutation (single commit at the end)
            # ----------------------------------------------------

            # 1) Ledger entry first: it generates the ID needed by
            #    the audit record (transaction_id is NOT NULL there),
            #    while reference_id is a plain nullable column with
            #    no FK, so it can be linked afterwards.
            transaction = self._build_transaction(
                wallet=wallet,
                amount=amount,
                description=(
                    note
                    or "Admin wallet recharge"
                ),
            )

            await self.wallet_repository.create_transaction(
                transaction,
            )

            # 2) Audit record linked to the ledger entry.
            recharge = self._build_recharge(
                wallet=wallet,
                user=user,
                transaction_id=transaction.id,
                amount=amount,
                balance_before=balance_before,
                balance_after=balance_after,
                admin_id=admin_id,
                admin_email=admin_email,
                note=note,
                idempotency_key=idempotency_key,
                ip_address=ip_address,
                user_agent=user_agent,
            )

            await self.repository.create_recharge(recharge)

            # 3) Complete the audit link on the ledger entry.
            transaction.reference_id = recharge.id

            # 4) Apply the balance change.
            wallet.coins_balance = balance_after

            # 5) Notify the target user (same transaction).
            notification = self._build_notification(
                user_id=user.id,
                amount=amount,
                balance_after=balance_after,
                transaction_id=transaction.id,
                recharge_id=recharge.id,
            )

            self.session.add(notification)

            # 6) Single atomic commit.
            await self.session.commit()

        except IntegrityError as exc:
            await self.session.rollback()

            if (
                idempotency_key is not None
                and _is_idempotency_violation(exc)
            ):
                # A concurrent duplicate request hit the unique
                # index. Re-read the winning record; only treat it
                # as idempotency when it actually exists.
                existing = (
                    await
                    self.repository.get_recharge_by_idempotency_key(
                        admin_id,
                        idempotency_key,
                    )
                )

                if existing is not None:
                    return existing

            raise

        except Exception:
            await self.session.rollback()
            raise

        return recharge

    # ============================================================
    # Read helpers (delegated to the repository)
    # ============================================================

    async def get_recharge(
        self,
        recharge_id: UUID | str,
    ) -> WalletAdminRecharge | None:
        return await self.repository.get_recharge_by_id(recharge_id)

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
        return await self.repository.list_recharges(
            wallet_number=wallet_number,
            user_id=user_id,
            admin_id=admin_id,
            status=status,
            created_from=created_from,
            created_to=created_to,
            search=search,
            offset=offset,
            limit=limit,
        )

    async def list_user_recharges(
        self,
        user_id: UUID | str,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[WalletAdminRecharge], int]:
        return await self.repository.list_user_recharges(
            user_id,
            offset=offset,
            limit=limit,
        )

    async def get_stats(
        self,
        *,
        created_from: datetime | None = None,
        created_to: datetime | None = None,
    ) -> dict:
        return await self.repository.get_recharge_stats(
            created_from=created_from,
            created_to=created_to,
        )
