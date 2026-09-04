"""Atomic store purchases and user ownership."""

from datetime import datetime, timezone
from dataclasses import dataclass
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.store_item import StoreItem, StoreItemCurrency
from app.models.store_ownership import StoreOwnership
from app.models.store_purchase import StorePurchase
from app.models.user import User
from app.models.user_point_transaction import UserPointTransactionType
from app.models.wallet_transaction import WalletTransactionType
from app.services.user_point.service import UserPointService
from app.services.wallet.service import WalletService


@dataclass(frozen=True)
class StorePurchaseResult:
    purchase: StorePurchase
    item: StoreItem
    ownership: StoreOwnership
    balance_after: int


class StorePurchaseService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def purchase(
        self,
        user_id: UUID,
        item_id: UUID,
        *,
        idempotency_key: str | None = None,
    ) -> StorePurchaseResult:
        if idempotency_key is not None:
            idempotency_key = idempotency_key.strip()
            if not idempotency_key or len(idempotency_key) > 100:
                raise ValueError("Invalid idempotency key")

        try:
            user = await self._get_locked_user(user_id)
            if user is None:
                raise ValueError("User not found")

            item = await self._get_locked_item(item_id)
            if item is None:
                raise ValueError("Store item not found")

            if idempotency_key is not None:
                existing = await self._get_purchase_by_key(
                    user_id,
                    idempotency_key,
                )
                if existing is not None:
                    if existing.item_id != item_id:
                        raise ValueError(
                            "Idempotency key was used for another item"
                        )
                    ownership = await self._get_ownership(user_id, item_id)
                    if ownership is None:
                        raise ValueError("Purchase ownership not found")
                    balance_after = await self._balance_after(
                        user_id,
                        existing.currency,
                    )
                    return StorePurchaseResult(
                        purchase=existing,
                        item=item,
                        ownership=ownership,
                        balance_after=balance_after,
                    )

            self._validate_item(item)

            purchase_id = uuid4()
            purchase_time = datetime.now(timezone.utc)
            amount = 0 if item.currency == StoreItemCurrency.FREE else item.price

            if item.currency == StoreItemCurrency.COINS:
                wallet_transaction = await WalletService(
                    self.session
                ).remove_coins(
                    user_id,
                    item.price,
                    transaction_type=WalletTransactionType.STORE_PURCHASE,
                    reference_type="STORE_PURCHASE",
                    reference_id=purchase_id,
                    extra_data={"item_id": str(item.id)},
                    commit=False,
                )
                balance_after = await self._wallet_balance(user_id)
            elif item.currency == StoreItemCurrency.POINTS:
                point_transaction = await UserPointService(
                    self.session
                ).remove_points(
                    user_id,
                    item.price,
                    transaction_type=UserPointTransactionType.STORE_PURCHASE,
                    reference_type="STORE_PURCHASE",
                    reference_id=purchase_id,
                    extra_data={"item_id": str(item.id)},
                    commit=False,
                )
                balance_after = point_transaction.balance_after
            else:
                balance_after = await self._user_points(user_id)

            ownership = await self._get_ownership(user_id, item_id)
            if ownership is None:
                ownership = StoreOwnership(
                    user_id=user_id,
                    item_id=item_id,
                    quantity=1,
                    expires_at=self._ownership_expiry(
                        item,
                        purchase_time,
                    ),
                )
                self.session.add(ownership)
            else:
                ownership.quantity += 1
                ownership.expires_at = self._ownership_expiry(
                    item,
                    purchase_time,
                )

            if item.stock is not None:
                item.stock -= 1

            purchase = StorePurchase(
                id=purchase_id,
                user_id=user_id,
                item_id=item_id,
                currency=item.currency,
                amount=amount,
                quantity=1,
                idempotency_key=idempotency_key,
                created_at=purchase_time,
            )
            self.session.add(purchase)
            await self.session.flush()
            await self.session.commit()

            return StorePurchaseResult(
                purchase=purchase,
                item=item,
                ownership=ownership,
                balance_after=balance_after,
            )
        except Exception:
            await self.session.rollback()
            raise

    async def list_ownership(self, user_id: UUID) -> list[StoreOwnership]:
        result = await self.session.execute(
            select(StoreOwnership)
            .options(selectinload(StoreOwnership.item))
            .where(StoreOwnership.user_id == user_id)
            .order_by(StoreOwnership.created_at)
        )
        return list(result.scalars().all())

    async def _get_locked_item(self, item_id: UUID) -> StoreItem | None:
        result = await self.session.execute(
            select(StoreItem)
            .where(StoreItem.id == item_id)
            .with_for_update()
        )
        return result.scalar_one_or_none()

    async def _get_locked_user(self, user_id: UUID) -> User | None:
        result = await self.session.execute(
            select(User)
            .where(User.id == user_id)
            .with_for_update()
        )
        return result.scalar_one_or_none()

    async def _get_purchase_by_key(
        self,
        user_id: UUID,
        idempotency_key: str,
    ) -> StorePurchase | None:
        result = await self.session.execute(
            select(StorePurchase).where(
                StorePurchase.user_id == user_id,
                StorePurchase.idempotency_key == idempotency_key,
            )
        )
        return result.scalar_one_or_none()

    async def _get_ownership(
        self,
        user_id: UUID,
        item_id: UUID,
    ) -> StoreOwnership | None:
        result = await self.session.execute(
            select(StoreOwnership)
            .where(
                StoreOwnership.user_id == user_id,
                StoreOwnership.item_id == item_id,
            )
            .with_for_update()
        )
        return result.scalar_one_or_none()

    @staticmethod
    def _validate_item(item: StoreItem) -> None:
        now = datetime.now(timezone.utc)
        if not item.is_active:
            raise ValueError("Store item is inactive")
        if item.available_from is not None and item.available_from > now:
            raise ValueError("Store item is not available yet")
        if item.available_until is not None and item.available_until < now:
            raise ValueError("Store item has expired")
        if item.stock is not None and item.stock <= 0:
            raise ValueError("Store item is out of stock")
        if item.price < 0:
            raise ValueError("Store item price is invalid")

    @staticmethod
    def _ownership_expiry(
        item: StoreItem,
        purchase_time: datetime,
    ) -> datetime | None:
        days = item.ownership_duration_days
        if days is None or days <= 0:
            return None
        from datetime import timedelta

        return purchase_time + timedelta(days=days)

    async def _wallet_balance(self, user_id: UUID) -> int:
        from app.models.wallet import UserWallet

        wallet_result = await self.session.execute(
            select(UserWallet.coins_balance).where(
                UserWallet.user_id == user_id
            )
        )
        balance = wallet_result.scalar_one_or_none()
        if balance is None:
            raise ValueError("Wallet not found")
        return int(balance)

    async def _balance_after(
        self,
        user_id: UUID,
        currency: StoreItemCurrency,
    ) -> int:
        if currency == StoreItemCurrency.COINS:
            return await self._wallet_balance(user_id)
        return await self._user_points(user_id)

    async def _user_points(self, user_id: UUID) -> int:
        result = await self.session.execute(
            select(User.points).where(User.id == user_id)
        )
        points = result.scalar_one_or_none()
        if points is None:
            raise ValueError("User not found")
        return int(points)
