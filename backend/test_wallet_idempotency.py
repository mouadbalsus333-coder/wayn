"""Wallet idempotency tests.

Tests:
1. Same idempotency key returns the same transfer.
2. Same idempotency key does not duplicate balances.
3. Same key with different amount is rejected.
4. Same key with different asset is rejected.
5. Same key with different receiver is rejected.
6. Concurrent requests with the same key create only one transfer.
7. Cleanup restores the original balances.
"""

import asyncio
import sys
from uuid import uuid4

from sqlalchemy import delete, func, select

from app.core.database import AsyncSessionLocal
from app.models.wallet import UserWallet
from app.models.wallet_transaction import WalletTransaction
from app.models.wallet_transfer import WalletTransfer
from app.models.wallet_transaction import WalletAsset
from app.services.wallet.service import WalletService


TRANSFER_AMOUNT = 100


async def get_test_wallets(
    session,
) -> tuple[UserWallet, UserWallet]:
    """Get two wallets without relying on created_at."""

    result = await session.execute(
        select(UserWallet)
        .order_by(UserWallet.id)
        .limit(2)
    )

    wallets = list(result.scalars().all())

    if len(wallets) < 2:
        raise RuntimeError(
            "At least two wallets are required for the test."
        )

    return wallets[0], wallets[1]


async def get_balances(
    session,
    wallet_id,
) -> tuple[int, int]:
    result = await session.execute(
        select(
            UserWallet.points_balance,
            UserWallet.coins_balance,
        ).where(
            UserWallet.id == wallet_id
        )
    )

    row = result.one_or_none()

    if row is None:
        raise RuntimeError(
            "Wallet not found while reading balance."
        )

    return row[0], row[1]


async def count_transfers(
    session,
    sender_wallet_id,
    idempotency_key: str,
) -> int:
    result = await session.execute(
        select(func.count(WalletTransfer.id)).where(
            WalletTransfer.sender_wallet_id
            == sender_wallet_id,
            WalletTransfer.idempotency_key
            == idempotency_key,
        )
    )

    return int(result.scalar_one())


async def cleanup_test_data(
    session,
    sender_wallet_id,
    receiver_wallet_id,
    test_keys: list[str],
) -> None:
    """Remove only transfers and transactions created by this test."""

    transfer_result = await session.execute(
        select(WalletTransfer.id).where(
            WalletTransfer.sender_wallet_id
            == sender_wallet_id,
            WalletTransfer.receiver_wallet_id
            == receiver_wallet_id,
            WalletTransfer.idempotency_key.in_(test_keys),
        )
    )

    transfer_ids = list(
        transfer_result.scalars().all()
    )

    if transfer_ids:
        await session.execute(
            delete(WalletTransaction).where(
                WalletTransaction.reference_type
                == "wallet_transfer",
                WalletTransaction.reference_id.in_(
                    transfer_ids
                ),
            )
        )

        await session.execute(
            delete(WalletTransfer).where(
                WalletTransfer.id.in_(transfer_ids)
            )
        )

    await session.commit()


async def main() -> None:
    print("=" * 60)
    print("WALLET IDEMPOTENCY TEST")
    print("=" * 60)

    test_keys = []

    async with AsyncSessionLocal() as session:
        # --------------------------------------------------------
        # Get test wallets
        # --------------------------------------------------------

        sender, receiver = await get_test_wallets(
            session
        )

        print(f"Sender wallet:   {sender.wallet_number}")
        print(f"Receiver wallet: {receiver.wallet_number}")

        # --------------------------------------------------------
        # Save original balances
        # --------------------------------------------------------

        original_sender_points = sender.points_balance
        original_receiver_points = (
            receiver.points_balance
        )

        print(
            f"Original sender points:   "
            f"{original_sender_points}"
        )
        print(
            f"Original receiver points: "
            f"{original_receiver_points}"
        )

        # --------------------------------------------------------
        # Ensure sender has enough points
        # --------------------------------------------------------

        required_points = TRANSFER_AMOUNT * 2

        if sender.points_balance < required_points:
            sender.points_balance = required_points
            await session.commit()
            await session.refresh(sender)

        # --------------------------------------------------------
        # Refresh balances after preparation
        # --------------------------------------------------------

        sender_points_before, _ = await get_balances(
            session,
            sender.id,
        )

        receiver_points_before, _ = await get_balances(
            session,
            receiver.id,
        )

        print(
            f"Test sender points:   "
            f"{sender_points_before}"
        )
        print(
            f"Test receiver points: "
            f"{receiver_points_before}"
        )

        # ========================================================
        # TEST 1
        # Same key twice
        # ========================================================

        print()
        print("=" * 60)
        print("TEST 1: SAME KEY TWICE")
        print("=" * 60)

        key_1 = f"wallet-test-{uuid4()}"

        test_keys.append(key_1)

        service = WalletService(session)

        transfer_1 = await service.transfer(
            sender_user_id=sender.user_id,
            receiver_wallet_number=receiver.wallet_number,
            asset=WalletAsset.POINTS,
            amount=TRANSFER_AMOUNT,
            description="Idempotency test 1",
            idempotency_key=key_1,
        )

        print(
            f"First transfer:  {transfer_1.id}"
        )

        sender_after_first, _ = await get_balances(
            session,
            sender.id,
        )

        receiver_after_first, _ = await get_balances(
            session,
            receiver.id,
        )

        transfer_2 = await service.transfer(
            sender_user_id=sender.user_id,
            receiver_wallet_number=receiver.wallet_number,
            asset=WalletAsset.POINTS,
            amount=TRANSFER_AMOUNT,
            description="Idempotency test 1",
            idempotency_key=key_1,
        )

        print(
            f"Second transfer: {transfer_2.id}"
        )

        sender_after_second, _ = await get_balances(
            session,
            sender.id,
        )

        receiver_after_second, _ = await get_balances(
            session,
            receiver.id,
        )

        assert transfer_1.id == transfer_2.id, (
            "FAIL: repeated idempotent request "
            "created a different transfer."
        )

        assert (
            sender_after_first
            == sender_after_second
        ), (
            "FAIL: sender balance changed "
            "on repeated request."
        )

        assert (
            receiver_after_first
            == receiver_after_second
        ), (
            "FAIL: receiver balance changed "
            "on repeated request."
        )

        transfer_count = await count_transfers(
            session,
            sender.id,
            key_1,
        )

        assert transfer_count == 1, (
            f"FAIL: expected 1 transfer, "
            f"found {transfer_count}."
        )

        print("PASS")

        # ========================================================
        # TEST 2
        # Same key + different amount
        # ========================================================

        print()
        print("=" * 60)
        print("TEST 2: SAME KEY + DIFFERENT AMOUNT")
        print("=" * 60)

        try:
            await service.transfer(
                sender_user_id=sender.user_id,
                receiver_wallet_number=receiver.wallet_number,
                asset=WalletAsset.POINTS,
                amount=TRANSFER_AMOUNT + 1,
                description="Idempotency test 1",
                idempotency_key=key_1,
            )

        except ValueError as exc:
            print(f"Expected rejection: {exc}")

            assert (
                "different transfer parameters"
                in str(exc)
            )

        else:
            raise AssertionError(
                "FAIL: different amount was accepted "
                "with the same idempotency key."
            )

        print("PASS")

        # ========================================================
        # TEST 3
        # Same key + different receiver
        # ========================================================

        print()
        print("=" * 60)
        print("TEST 3: SAME KEY + DIFFERENT RECEIVER")
        print("=" * 60)

        # Find another wallet.
        result = await session.execute(
            select(UserWallet)
            .where(
                UserWallet.id.notin_(
                    [sender.id, receiver.id]
                )
            )
            .order_by(UserWallet.id)
            .limit(1)
        )

        third_wallet = result.scalar_one_or_none()

        if third_wallet is None:
            print(
                "SKIPPED: no third wallet available."
            )
        else:
            try:
                await service.transfer(
                    sender_user_id=sender.user_id,
                    receiver_wallet_number=(
                        third_wallet.wallet_number
                    ),
                    asset=WalletAsset.POINTS,
                    amount=TRANSFER_AMOUNT,
                    description="Idempotency test 1",
                    idempotency_key=key_1,
                )

            except ValueError as exc:
                print(
                    f"Expected rejection: {exc}"
                )

                assert (
                    "different receiver wallet"
                    in str(exc)
                )

            else:
                raise AssertionError(
                    "FAIL: different receiver was "
                    "accepted with the same key."
                )

            print("PASS")

        # ========================================================
        # TEST 4
        # Same key + different asset
        # ========================================================

        print()
        print("=" * 60)
        print("TEST 4: SAME KEY + DIFFERENT ASSET")
        print("=" * 60)

        try:
            await service.transfer(
                sender_user_id=sender.user_id,
                receiver_wallet_number=receiver.wallet_number,
                asset=WalletAsset.COINS,
                amount=TRANSFER_AMOUNT,
                description="Idempotency test 1",
                idempotency_key=key_1,
            )

        except ValueError as exc:
            print(
                f"Expected rejection: {exc}"
            )

            assert (
                "different transfer parameters"
                in str(exc)
            )

        else:
            raise AssertionError(
                "FAIL: different asset was accepted "
                "with the same idempotency key."
            )

        print("PASS")

        # ========================================================
        # TEST 5
        # Concurrent same-key requests
        # ========================================================

        print()
        print("=" * 60)
        print("TEST 5: CONCURRENT SAME-KEY REQUESTS")
        print("=" * 60)

        concurrent_key = (
            f"wallet-concurrent-{uuid4()}"
        )

        test_keys.append(concurrent_key)

        # Make sure enough balance exists for one transfer.
        sender_points, _ = await get_balances(
            session,
            sender.id,
        )

        if sender_points < TRANSFER_AMOUNT:
            raise AssertionError(
                "Sender does not have enough points "
                "for concurrency test."
            )

        # Release any transaction/row locks held by the main
        # test session before starting concurrent requests.
        # Each concurrent request uses its own AsyncSession and
        # must be able to acquire the sender wallet lock.
        await session.commit()

        async def execute_transfer(
            number: int,
        ):
            async with AsyncSessionLocal() as task_session:
                task_service = WalletService(
                    task_session
                )

                try:
                    transfer = (
                        await task_service.transfer(
                            sender_user_id=sender.user_id,
                            receiver_wallet_number=(
                                receiver.wallet_number
                            ),
                            asset=WalletAsset.POINTS,
                            amount=TRANSFER_AMOUNT,
                            description=(
                                "Concurrent idempotency test"
                            ),
                            idempotency_key=(
                                concurrent_key
                            ),
                        )
                    )

                    return {
                        "number": number,
                        "status": "SUCCESS",
                        "transfer_id": str(
                            transfer.id
                        ),
                    }

                except Exception as exc:
                    return {
                        "number": number,
                        "status": "FAILED",
                        "error": str(exc),
                    }

        results = await asyncio.gather(
            execute_transfer(1),
            execute_transfer(2),
            execute_transfer(3),
            execute_transfer(4),
            execute_transfer(5),
        )

        for result in results:
            print(result)

        successful = [
            result
            for result in results
            if result["status"] == "SUCCESS"
        ]

        assert len(successful) == 5, (
            "FAIL: repeated concurrent requests "
            "should all resolve to the same "
            "idempotent transfer."
        )

        transfer_ids = {
            result["transfer_id"]
            for result in successful
        }

        assert len(transfer_ids) == 1, (
            "FAIL: concurrent requests created "
            "multiple transfer IDs."
        )

        concurrent_count = (
            await count_transfers(
                session,
                sender.id,
                concurrent_key,
            )
        )

        assert concurrent_count == 1, (
            f"FAIL: expected exactly 1 transfer "
            f"for concurrent key, found "
            f"{concurrent_count}."
        )

        print(
            "Exactly one database transfer was created."
        )

        print("PASS")

        # ========================================================
        # TEST 6
        # Balance verification
        # ========================================================

        print()
        print("=" * 60)
        print("TEST 6: BALANCE VERIFICATION")
        print("=" * 60)

        sender_final, _ = await get_balances(
            session,
            sender.id,
        )

        receiver_final, _ = await get_balances(
            session,
            receiver.id,
        )

        expected_sender = (
            sender_points_before
            - TRANSFER_AMOUNT
            - TRANSFER_AMOUNT
        )

        # One normal idempotent transfer + one
        # concurrent idempotent transfer.
        expected_receiver = (
            receiver_points_before
            + TRANSFER_AMOUNT
            + TRANSFER_AMOUNT
        )

        print(
            f"Sender expected:   {expected_sender}"
        )
        print(
            f"Sender actual:     {sender_final}"
        )
        print(
            f"Receiver expected: {expected_receiver}"
        )
        print(
            f"Receiver actual:   {receiver_final}"
        )

        assert sender_final == expected_sender, (
            "FAIL: sender balance is incorrect."
        )

        assert receiver_final == expected_receiver, (
            "FAIL: receiver balance is incorrect."
        )

        print("PASS")

        # ========================================================
        # CLEANUP
        # ========================================================

        print()
        print("=" * 60)
        print("CLEANUP")
        print("=" * 60)

        # Restore balances.
        sender.points_balance = (
            original_sender_points
        )

        receiver.points_balance = (
            original_receiver_points
        )

        await session.flush()

        await cleanup_test_data(
            session,
            sender.id,
            receiver.id,
            test_keys,
        )

        # Verify cleanup.
        sender_clean, _ = await get_balances(
            session,
            sender.id,
        )

        receiver_clean, _ = await get_balances(
            session,
            receiver.id,
        )

        assert (
            sender_clean == original_sender_points
        ), (
            "FAIL: sender balance was not restored."
        )

        assert (
            receiver_clean
            == original_receiver_points
        ), (
            "FAIL: receiver balance was not restored."
        )

        print(
            f"Sender restored:   {sender_clean}"
        )
        print(
            f"Receiver restored: {receiver_clean}"
        )

        print("Cleanup PASS")

    print()
    print("=" * 60)
    print("ALL IDEMPOTENCY TESTS PASSED")
    print("=" * 60)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nTest interrupted.")
        sys.exit(1)
    except Exception as exc:
        print()
        print("=" * 60)
        print("IDEMPOTENCY TEST FAILED")
        print("=" * 60)
        print(type(exc).__name__ + ":", exc)
        sys.exit(1)
