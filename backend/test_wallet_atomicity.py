import asyncio
from uuid import UUID

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.models.wallet import UserWallet
from app.models.wallet_transaction import WalletTransaction
from app.models.wallet_transfer import WalletTransfer


SENDER_WALLET = "W37440145803"
RECEIVER_WALLET = "W48207779586"


async def get_wallet(session, wallet_number: str):
    result = await session.execute(
        select(UserWallet).where(
            UserWallet.wallet_number == wallet_number
        )
    )
    return result.scalar_one()


async def main():
    async with AsyncSessionLocal() as session:
        sender = await get_wallet(session, SENDER_WALLET)
        receiver = await get_wallet(session, RECEIVER_WALLET)

        original_sender_points = sender.points_balance
        original_receiver_points = receiver.points_balance

        transfer_count_before = (
            await session.execute(
                select(WalletTransfer).where(
                    WalletTransfer.sender_wallet_id == sender.id,
                    WalletTransfer.receiver_wallet_id == receiver.id,
                )
            )
        )

        transfers_before = len(
            transfer_count_before.scalars().all()
        )

        print("=== BEFORE ===")
        print("Sender:", sender.wallet_number)
        print("Sender points:", original_sender_points)
        print("Receiver:", receiver.wallet_number)
        print("Receiver points:", original_receiver_points)
        print("Existing transfers:", transfers_before)

        try:
            async with session.begin_nested():

                sender.points_balance -= 100
                receiver.points_balance += 100

                transfer = WalletTransfer(
                    sender_wallet_id=sender.id,
                    receiver_wallet_id=receiver.id,
                    asset="POINTS",
                    amount=100,
                    status="PENDING",
                    description="ATOMICITY TEST - SHOULD ROLLBACK",
                )

                session.add(transfer)

                await session.flush()

                transaction = WalletTransaction(
                    wallet_id=sender.id,
                    asset="POINTS",
                    type="TRANSFER",
                    status="CONFIRMED",
                    amount=-100,
                    description="ATOMICITY TEST - SHOULD ROLLBACK",
                    reference_type="wallet_transfer",
                    reference_id=transfer.id,
                    extra_data={},
                )

                session.add(transaction)

                await session.flush()

                print("\nForcing failure after balance changes...")

                raise RuntimeError(
                    "INTENTIONAL FAILURE FOR ATOMICITY TEST"
                )

        except RuntimeError as exc:
            print("Expected failure:", exc)

        await session.rollback()

    # ---------------------------------------------------------
    # Fresh session: verify database state
    # ---------------------------------------------------------

    async with AsyncSessionLocal() as session:
        sender = await get_wallet(session, SENDER_WALLET)
        receiver = await get_wallet(session, RECEIVER_WALLET)

        transfer_result = await session.execute(
            select(WalletTransfer).where(
                WalletTransfer.sender_wallet_id == sender.id,
                WalletTransfer.receiver_wallet_id == receiver.id,
                WalletTransfer.description
                == "ATOMICITY TEST - SHOULD ROLLBACK",
            )
        )

        remaining_transfers = transfer_result.scalars().all()

        transaction_result = await session.execute(
            select(WalletTransaction).where(
                WalletTransaction.description
                == "ATOMICITY TEST - SHOULD ROLLBACK"
            )
        )

        remaining_transactions = (
            transaction_result.scalars().all()
        )

        print("\n=== AFTER ROLLBACK ===")
        print("Sender points:", sender.points_balance)
        print("Expected sender points:", original_sender_points)

        print("Receiver points:", receiver.points_balance)
        print(
            "Expected receiver points:",
            original_receiver_points,
        )

        print(
            "Remaining test transfers:",
            len(remaining_transfers),
        )

        print(
            "Remaining test transactions:",
            len(remaining_transactions),
        )

        assert (
            sender.points_balance
            == original_sender_points
        ), "Sender balance changed!"

        assert (
            receiver.points_balance
            == original_receiver_points
        ), "Receiver balance changed!"

        assert (
            len(remaining_transfers) == 0
        ), "Transfer was not rolled back!"

        assert (
            len(remaining_transactions) == 0
        ), "Transaction was not rolled back!"

        print("\n========================================")
        print("ATOMICITY TEST PASSED")
        print("All changes were rolled back successfully.")
        print("========================================")


if __name__ == "__main__":
    asyncio.run(main())