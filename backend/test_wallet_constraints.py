import asyncio

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from app.core.database import engine


async def test_constraint(conn, name, sql, params):
    print(f"\n--- {name} ---")

    trans = await conn.begin()

    try:
        await conn.execute(text(sql), params)

        print("ERROR: Database accepted the invalid value!")

    except IntegrityError as exc:
        print("PASS: Database rejected the invalid value.")
        print(f"Constraint error: {exc.orig}")

    finally:
        await trans.rollback()
        print("ROLLBACK: No data was changed.")


async def main():
    async with engine.connect() as conn:

        # --------------------------------------------------------
        # 1. Invalid transfer amount
        # --------------------------------------------------------
        await test_constraint(
            conn,
            "Negative transfer amount",
            """
            INSERT INTO wallet_transfers (
                sender_wallet_id,
                receiver_wallet_id,
                asset,
                amount
            )
            SELECT
                w1.id,
                w2.id,
                'POINTS',
                -1
            FROM user_wallets w1
            CROSS JOIN user_wallets w2
            WHERE w1.id <> w2.id
            LIMIT 1
            """,
            {},
        )

        # --------------------------------------------------------
        # 2. Same sender and receiver wallet
        # --------------------------------------------------------
        await test_constraint(
            conn,
            "Same sender and receiver wallet",
            """
            INSERT INTO wallet_transfers (
                sender_wallet_id,
                receiver_wallet_id,
                asset,
                amount
            )
            SELECT
                id,
                id,
                'POINTS',
                1
            FROM user_wallets
            LIMIT 1
            """,
            {},
        )

        # --------------------------------------------------------
        # 3. Negative points balance
        # --------------------------------------------------------
        await test_constraint(
            conn,
            "Negative points balance",
            """
            UPDATE user_wallets
            SET points_balance = -1
            WHERE id = (
                SELECT id
                FROM user_wallets
                LIMIT 1
            )
            """,
            {},
        )

        # --------------------------------------------------------
        # 4. Negative coins balance
        # --------------------------------------------------------
        await test_constraint(
            conn,
            "Negative coins balance",
            """
            UPDATE user_wallets
            SET coins_balance = -1
            WHERE id = (
                SELECT id
                FROM user_wallets
                LIMIT 1
            )
            """,
            {},
        )

        print("\n========================================")
        print("All database constraint tests completed.")
        print("All transactions were rolled back.")
        print("========================================")


if __name__ == "__main__":
    asyncio.run(main())
