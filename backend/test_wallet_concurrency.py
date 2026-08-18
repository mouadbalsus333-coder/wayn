import asyncio

from sqlalchemy import delete, select, update

from app.core.database import AsyncSessionLocal
from app.models.wallet import UserWallet
from app.models.wallet_transaction import (
    WalletAsset,
    WalletTransaction,
    WalletTransactionType,
)
from app.models.wallet_transfer import WalletTransfer
from app.services.wallet.service import WalletService


SENDER_USER_ID = "90f71b3e-a2da-47af-884d-c275fe8c7897"
RECEIVER_WALLET_NUMBER = "W48207779586"

TEST_DESCRIPTION_PREFIX = "Concurrency test #"
TEST_AMOUNT = 100


async def main():
    # ------------------------------------------------------------
    # 1. Read current sender state
    # ------------------------------------------------------------
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(UserWallet).where(
                UserWallet.user_id == SENDER_USER_ID
            )
        )

        sender = result.scalar_one()

        original_balance = sender.points_balance

        print("Sender wallet:", sender.wallet_number)
        print("Original points:", original_balance)

        if original_balance < TEST_AMOUNT:
            raise RuntimeError(
                "Sender does not have enough points for the test."
            )

        # Set exactly 100 points so only ONE concurrent transfer
        # of 100 points can succeed.
        sender.points_balance = TEST_AMOUNT

        await session.commit()

        print(
            f"Temporary points balance: {TEST_AMOUNT}"
        )

    # ------------------------------------------------------------
    # 2. Run two concurrent transfers
    # ------------------------------------------------------------
    async def attempt(number: int):
        async with AsyncSessionLocal() as session:
            service = WalletService(session)

            try:
                transfer = await service.transfer(
                    sender_user_id=SENDER_USER_ID,
                    receiver_wallet_number=RECEIVER_WALLET_NUMBER,
                    asset=WalletAsset.POINTS,
                    amount=TEST_AMOUNT,
                    description=(
                        f"{TEST_DESCRIPTION_PREFIX}{number}"
                    ),
                )

                return {
                    "number": number,
                    "status": "SUCCESS",
                    "transfer_id": str(transfer.id),
                }

            except Exception as exc:
                return {
                    "number": number,
                    "status": "FAILED",
                    "error": str(exc),
                }

    results = await asyncio.gather(
        attempt(1),
        attempt(2),
    )

    print()
    print("=== CONCURRENCY RESULTS ===")

    for result in results:
        print(result)

    # ------------------------------------------------------------
    # 3. Inspect balances after concurrent operations
    # ------------------------------------------------------------
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(UserWallet).where(
                UserWallet.user_id == SENDER_USER_ID
            )
        )
        sender = result.scalar_one()

        result = await session.execute(
            select(UserWallet).where(
                UserWallet.wallet_number
                == RECEIVER_WALLET_NUMBER
            )
        )
        receiver = result.scalar_one()

        print()
        print("=== BALANCES AFTER TEST ===")
        print("Sender points:", sender.points_balance)
        print("Receiver points:", receiver.points_balance)

    # ------------------------------------------------------------
    # 4. Cleanup test transactions and restore balances
    # ------------------------------------------------------------
    async with AsyncSessionLocal() as session:
        # Find test transfers.
        result = await session.execute(
            select(WalletTransfer).where(
                WalletTransfer.description.like(
                    f"{TEST_DESCRIPTION_PREFIX}%"
                )
            )
        )

        transfers = list(result.scalars().all())
        transfer_ids = [transfer.id for transfer in transfers]

        # Delete test ledger entries first.
        if transfer_ids:
            await session.execute(
                delete(WalletTransaction).where(
                    WalletTransaction.reference_id.in_(
                        transfer_ids
                    )
                )
            )

        # Delete test transfer records.
        if transfer_ids:
            await session.execute(
                delete(WalletTransfer).where(
                    WalletTransfer.id.in_(transfer_ids)
                )
            )

        # Restore the sender's original balance.
        await session.execute(
            update(UserWallet)
            .where(
                UserWallet.user_id == SENDER_USER_ID
            )
            .values(points_balance=original_balance)
        )

        # Restore receiver balance by removing the test amount
        # for every successful transfer.
        successful_count = sum(
            1
            for result in results
            if result["status"] == "SUCCESS"
        )

        if successful_count:
            await session.execute(
                update(UserWallet)
                .where(
                    UserWallet.wallet_number
                    == RECEIVER_WALLET_NUMBER
                )
                .values(
                    points_balance=(
                        UserWallet.points_balance
                        - TEST_AMOUNT * successful_count
                    )
                )
            )

        await session.commit()

    # ------------------------------------------------------------
    # 5. Verify cleanup
    # ------------------------------------------------------------
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(UserWallet).where(
                UserWallet.user_id == SENDER_USER_ID
            )
        )
        sender = result.scalar_one()

        result = await session.execute(
            select(UserWallet).where(
                UserWallet.wallet_number
                == RECEIVER_WALLET_NUMBER
            )
        )
        receiver = result.scalar_one()

        result = await session.execute(
            select(WalletTransfer).where(
                WalletTransfer.description.like(
                    f"{TEST_DESCRIPTION_PREFIX}%"
                )
            )
        )

        remaining_transfers = list(
            result.scalars().all()
        )

        print()
        print("=== CLEANUP VERIFICATION ===")
        print("Sender points:", sender.points_balance)
        print("Expected sender points:", original_balance)
        print("Receiver points:", receiver.points_balance)
        print("Remaining test transfers:", len(remaining_transfers))

        if sender.points_balance != original_balance:
            raise RuntimeError(
                "CLEANUP FAILED: sender balance changed."
            )

        if remaining_transfers:
            raise RuntimeError(
                "CLEANUP FAILED: test transfers remain."
            )

    print()
    print("========================================")
    print("CONCURRENCY TEST COMPLETED")
    print("Cleanup completed successfully.")
    print("========================================")


if __name__ == "__main__":
    asyncio.run(main())