"""Wallet API and business-logic QA tests for WAYN."""

from __future__ import annotations

import uuid
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import select, text

import app.core.database as database_module
from app.main import app
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

pytestmark = pytest.mark.anyio


# ============================================================
# Helpers
# ============================================================


def unique_suffix() -> str:
    return uuid.uuid4().hex[:10]


async def register_user(
    client: AsyncClient,
    *,
    prefix: str = "wallet_user",
) -> tuple[str, dict]:
    """Register a fresh user and return (access_token, response_data)."""

    suffix = unique_suffix()

    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": f"{prefix}_{suffix}@wayntest.com",
            "password": "WalletPass123!",
            "full_name": f"Wallet Test User {suffix}",
            "username": f"{prefix}_{suffix}",
        },
    )

    assert response.status_code == 201, response.text

    data = response.json()

    return data["access_token"], data


async def get_wallet_from_db(
    wallet_number: str,
) -> UserWallet:
    """Load a wallet directly from the test database."""

    async with database_module.AsyncSessionLocal() as session:
        result = await session.execute(
            select(UserWallet).where(
                UserWallet.wallet_number == wallet_number
            )
        )

        wallet = result.scalar_one_or_none()

        assert wallet is not None, (
            f"Wallet {wallet_number!r} was not found in the database"
        )

        return wallet


async def set_wallet_balances(
    wallet_number: str,
    *,
    points: int | None = None,
    coins: int | None = None,
) -> None:
    """Set test balances directly in the test database."""

    async with database_module.AsyncSessionLocal() as session:
        result = await session.execute(
            select(UserWallet).where(
                UserWallet.wallet_number == wallet_number
            )
        )

        wallet = result.scalar_one()

        if points is not None:
            wallet.points_balance = points

        if coins is not None:
            wallet.coins_balance = coins

        await session.commit()


async def set_wallet_status(
    wallet_number: str,
    status: WalletStatus,
    *,
    suspended_until=None,
) -> None:
    """Set wallet status directly for protection tests."""

    async with database_module.AsyncSessionLocal() as session:
        result = await session.execute(
            select(UserWallet).where(
                UserWallet.wallet_number == wallet_number
            )
        )

        wallet = result.scalar_one()

        wallet.status = status
        wallet.suspended_until = suspended_until

        await session.commit()


async def block_wallet_transfers(
    wallet_number: str,
    *,
    blocked_until=None,
    reason: str = "QA test transfer block",
) -> None:
    """Block outgoing transfers for a test wallet."""

    async with database_module.AsyncSessionLocal() as session:
        result = await session.execute(
            select(UserWallet).where(
                UserWallet.wallet_number == wallet_number
            )
        )

        wallet = result.scalar_one()

        wallet.transfers_blocked_until = blocked_until
        wallet.transfers_block_reason = reason

        await session.commit()


async def get_wallet_transactions(
    wallet_number: str,
) -> list[WalletTransaction]:
    """Return all ledger transactions belonging to a wallet."""

    async with database_module.AsyncSessionLocal() as session:
        result = await session.execute(
            select(WalletTransaction)
            .join(
                UserWallet,
                UserWallet.id == WalletTransaction.wallet_id,
            )
            .where(
                UserWallet.wallet_number == wallet_number
            )
            .order_by(WalletTransaction.created_at.asc())
        )

        return list(result.scalars().all())


async def get_transfer_by_id(
    transfer_id: str,
) -> WalletTransfer:
    """Load a wallet transfer from the test database."""

    async with database_module.AsyncSessionLocal() as session:
        result = await session.execute(
            select(WalletTransfer).where(
                WalletTransfer.id == transfer_id
            )
        )

        transfer = result.scalar_one_or_none()

        assert transfer is not None, (
            f"Transfer {transfer_id!r} was not found"
        )

        return transfer


async def get_user_wallet_number(
    user_id,
) -> str:
    """Get a user's wallet number from the database."""

    async with database_module.AsyncSessionLocal() as session:
        result = await session.execute(
            select(UserWallet.wallet_number)
            .where(UserWallet.user_id == user_id)
        )

        wallet_number = result.scalar_one_or_none()

        assert wallet_number is not None

        return wallet_number


async def get_user_by_email(email: str) -> User:
    """Load a user by email."""

    async with database_module.AsyncSessionLocal() as session:
        result = await session.execute(
            select(User).where(User.email == email)
        )

        user = result.scalar_one_or_none()

        assert user is not None

        return user


# ============================================================
# Wallet creation / retrieval
# ============================================================


async def test_get_my_wallet_creates_wallet(
    user_token,
):
    """GET /wallet should create the user's wallet if missing."""

    token, user_data = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {token}",
            },
        )

    assert response.status_code == 200, response.text

    data = response.json()

    assert data["id"]
    assert data["user_id"]
    assert data["wallet_number"]
    assert data["wallet_number"].startswith("W")
    assert len(data["wallet_number"]) == 12
    assert data["points_balance"] == 0
    assert data["coins_balance"] == 0

    wallet = await get_wallet_from_db(
        data["wallet_number"]
    )

    assert str(wallet.user_id) == str(data["user_id"])
    assert wallet.points_balance == 0
    assert wallet.coins_balance == 0
    assert wallet.status == WalletStatus.ACTIVE


async def test_get_my_wallet_is_idempotent(
    user_token,
):
    """Repeated GET /wallet calls must return the same wallet."""

    token, _ = user_token

    headers = {
        "Authorization": f"Bearer {token}",
    }

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        first = await client.get(
            "/api/v1/wallet",
            headers=headers,
        )

        second = await client.get(
            "/api/v1/wallet",
            headers=headers,
        )

    assert first.status_code == 200, first.text
    assert second.status_code == 200, second.text

    first_data = first.json()
    second_data = second.json()

    assert first_data["id"] == second_data["id"]
    assert (
        first_data["wallet_number"]
        == second_data["wallet_number"]
    )


# ============================================================
# Wallet authentication
# ============================================================


async def test_get_wallet_requires_authentication():
    """Wallet endpoints must reject unauthenticated requests."""

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        response = await client.get(
            "/api/v1/wallet"
        )

    assert response.status_code in {401, 403}


async def test_wallet_transactions_requires_authentication():
    """Transaction history must require authentication."""

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        response = await client.get(
            "/api/v1/wallet/transactions"
        )

    assert response.status_code in {401, 403}


# ============================================================
# Balance visibility
# ============================================================


async def test_wallet_returns_current_balances(
    user_token,
):
    """Wallet response must expose the current database balances."""

    token, _ = user_token

    headers = {
        "Authorization": f"Bearer {token}",
    }

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        wallet_response = await client.get(
            "/api/v1/wallet",
            headers=headers,
        )

    assert wallet_response.status_code == 200

    wallet_data = wallet_response.json()

    await set_wallet_balances(
        wallet_data["wallet_number"],
        points=1500,
        coins=750,
    )

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        response = await client.get(
            "/api/v1/wallet",
            headers=headers,
        )

    assert response.status_code == 200

    data = response.json()

    assert data["points_balance"] == 1500
    assert data["coins_balance"] == 750


# ============================================================
# Transactions API
# ============================================================


async def test_wallet_transactions_empty_for_new_wallet(
    user_token,
):
    """A newly created wallet should have no transactions."""

    token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        response = await client.get(
            "/api/v1/wallet/transactions",
            headers={
                "Authorization": f"Bearer {token}",
            },
        )

    assert response.status_code == 200, response.text
    assert response.json() == []


async def test_wallet_transactions_pagination_validation(
    user_token,
):
    """Transactions endpoint must enforce limit and offset constraints."""

    token, _ = user_token

    headers = {
        "Authorization": f"Bearer {token}",
    }

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        invalid_limit_low = await client.get(
            "/api/v1/wallet/transactions?limit=0",
            headers=headers,
        )

        invalid_limit_high = await client.get(
            "/api/v1/wallet/transactions?limit=101",
            headers=headers,
        )

        invalid_offset = await client.get(
            "/api/v1/wallet/transactions?offset=-1",
            headers=headers,
        )

    assert invalid_limit_low.status_code == 422
    assert invalid_limit_high.status_code == 422
    assert invalid_offset.status_code == 422


# ============================================================
# Transfer setup
# ============================================================


async def create_two_wallet_users(
    client: AsyncClient,
) -> tuple[
    str,
    dict,
    str,
    dict,
]:
    """Create two users and initialize both wallets."""

    sender_token, sender_data = await register_user(
        client,
        prefix="sender",
    )

    receiver_token, receiver_data = await register_user(
        client,
        prefix="receiver",
    )

    sender_wallet_response = await client.get(
        "/api/v1/wallet",
        headers={
            "Authorization": f"Bearer {sender_token}",
        },
    )

    receiver_wallet_response = await client.get(
        "/api/v1/wallet",
        headers={
            "Authorization": f"Bearer {receiver_token}",
        },
    )

    assert sender_wallet_response.status_code == 200
    assert receiver_wallet_response.status_code == 200

    sender_wallet = sender_wallet_response.json()
    receiver_wallet = receiver_wallet_response.json()

    return (
        sender_token,
        sender_wallet,
        receiver_token,
        receiver_wallet,
    )


# ============================================================
# Successful transfers
# ============================================================


async def test_transfer_points_successfully(
    user_token,
):
    """A valid points transfer must update both wallets."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, receiver_data = await register_user(
            client,
            prefix="points_receiver",
        )

        sender_wallet_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_wallet_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        assert sender_wallet_response.status_code == 200
        assert receiver_wallet_response.status_code == 200

        sender_wallet = sender_wallet_response.json()
        receiver_wallet = receiver_wallet_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            points=1000,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.POINTS.value,
                "amount": 250,
                "description": "QA points transfer",
                "idempotency_key": (
                    f"points-{unique_suffix()}"
                ),
            },
        )

    assert response.status_code == 200, response.text

    transfer_data = response.json()

    assert transfer_data["asset"] == WalletAsset.POINTS.value
    assert transfer_data["amount"] == 250
    assert transfer_data["status"] == (
        WalletTransferStatus.CONFIRMED.value
    )
    assert transfer_data["completed_at"] is not None

    sender_wallet_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_wallet_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    assert sender_wallet_after.points_balance == 750
    assert receiver_wallet_after.points_balance == 250
    assert sender_wallet_after.coins_balance == 0
    assert receiver_wallet_after.coins_balance == 0


async def test_transfer_coins_successfully(
    user_token,
):
    """A valid coins transfer must update both wallets."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="coins_receiver",
        )

        sender_wallet_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_wallet_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_wallet_response.json()
        receiver_wallet = receiver_wallet_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=2000,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 600,
                "description": "QA coins transfer",
            },
        )

    assert response.status_code == 200, response.text

    sender_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    assert sender_after.coins_balance == 1400
    assert receiver_after.coins_balance == 600


# ============================================================
# Transfer validation
# ============================================================


@pytest.mark.parametrize(
    "asset",
    [
        WalletAsset.POINTS.value,
        WalletAsset.COINS.value,
    ],
)
async def test_transfer_rejects_insufficient_balance(
    user_token,
    asset,
):
    """Transfers must fail when the sender lacks sufficient balance."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="insufficient_receiver",
        )

        sender_wallet_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_wallet_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_wallet_response.json()
        receiver_wallet = receiver_wallet_response.json()

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": asset,
                "amount": 1,
            },
        )

    assert response.status_code == 400

    assert (
        response.json()["detail"]
        in {
            "Insufficient points balance",
            "Insufficient coins balance",
        }
    )

    sender_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    assert sender_after.points_balance == 0
    assert sender_after.coins_balance == 0
    assert receiver_after.points_balance == 0
    assert receiver_after.coins_balance == 0


async def test_transfer_rejects_zero_amount(
    user_token,
):
    """Transfer amount must be greater than zero."""

    token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="zero_receiver",
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        receiver_wallet = receiver_response.json()

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 0,
            },
        )

    assert response.status_code == 422


async def test_transfer_rejects_negative_amount(
    user_token,
):
    """Negative transfer amounts must be rejected."""

    token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="negative_receiver",
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        receiver_wallet = receiver_response.json()

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": -100,
            },
        )

    assert response.status_code == 422


async def test_transfer_rejects_same_wallet(
    user_token,
):
    """A wallet cannot transfer funds to itself."""

    token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        wallet_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {token}",
            },
        )

        wallet = wallet_response.json()

        await set_wallet_balances(
            wallet["wallet_number"],
            coins=1000,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {token}",
            },
            json={
                "receiver_wallet_number": wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 100,
            },
        )

    assert response.status_code == 400
    assert response.json()["detail"] == (
        "Cannot transfer to the same wallet"
    )


async def test_transfer_rejects_missing_receiver_wallet(
    user_token,
):
    """Unknown wallet numbers must return 404."""

    token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        sender_wallet_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {token}",
            },
        )

        sender_wallet = sender_wallet_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=1000,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {token}",
            },
            json={
                "receiver_wallet_number": "W99999999999",
                "asset": WalletAsset.COINS.value,
                "amount": 100,
            },
        )

    assert response.status_code == 404
    assert response.json()["detail"] == (
        "Receiver wallet not found"
    )


# ============================================================
# Wallet status protection
# ============================================================


async def test_suspended_wallet_cannot_send_transfers(
    user_token,
):
    """Suspended wallets must not be allowed to send transfers."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="suspended_receiver",
        )

        sender_wallet_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_wallet_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_wallet_response.json()
        receiver_wallet = receiver_wallet_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=1000,
        )

        await set_wallet_status(
            sender_wallet["wallet_number"],
            WalletStatus.SUSPENDED,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 100,
            },
        )

    assert response.status_code == 400
    assert response.json()["detail"] == (
        "Wallet is suspended"
    )

    sender_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    assert sender_after.coins_balance == 1000
    assert receiver_after.coins_balance == 0


async def test_hidden_wallet_cannot_send_transfers(
    user_token,
):
    """Hidden wallets must not be allowed to send transfers."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="hidden_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            points=500,
        )

        await set_wallet_status(
            sender_wallet["wallet_number"],
            WalletStatus.HIDDEN,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.POINTS.value,
                "amount": 100,
            },
        )

    assert response.status_code == 400
    assert response.json()["detail"] == (
        "Wallet is hidden"
    )


async def test_transfer_block_prevents_outgoing_transfer(
    user_token,
):
    """A temporary outgoing-transfer block must be enforced."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="blocked_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=1000,
        )

        await block_wallet_transfers(
            sender_wallet["wallet_number"],
            reason="QA temporary block",
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 100,
            },
        )

    assert response.status_code == 400
    assert response.json()["detail"] == (
        "Wallet transfers are temporarily blocked"
    )


async def test_inactive_receiver_cannot_receive_transfer(
    user_token,
):
    """A non-active receiver wallet must reject incoming transfers."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="inactive_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=1000,
        )

        await set_wallet_status(
            receiver_wallet["wallet_number"],
            WalletStatus.SUSPENDED,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 100,
            },
        )

    assert response.status_code == 400
    assert response.json()["detail"] == (
        "Receiver wallet is not active"
    )

    sender_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    assert sender_after.coins_balance == 1000
    assert receiver_after.coins_balance == 0


# ============================================================
# Idempotency
# ============================================================


async def test_transfer_idempotency_returns_original_transfer(
    user_token,
):
    """
    Repeating the same request with the same idempotency key
    must not create another transfer or debit the sender twice.
    """

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="idempotent_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=1000,
        )

        idempotency_key = (
            f"idempotency-{unique_suffix()}"
        )

        payload = {
            "receiver_wallet_number": receiver_wallet[
                "wallet_number"
            ],
            "asset": WalletAsset.COINS.value,
            "amount": 300,
            "description": "Idempotent transfer",
            "idempotency_key": idempotency_key,
        }

        first_response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json=payload,
        )

        second_response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json=payload,
        )

    assert first_response.status_code == 200, (
        first_response.text
    )
    assert second_response.status_code == 200, (
        second_response.text
    )

    first_transfer = first_response.json()
    second_transfer = second_response.json()

    assert first_transfer["id"] == second_transfer["id"]

    sender_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    assert sender_after.coins_balance == 700
    assert receiver_after.coins_balance == 300


async def test_idempotency_key_rejects_different_amount(
    user_token,
):
    """The same idempotency key cannot be reused with another amount."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="idempotency_amount_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=2000,
        )

        key = f"same-key-{unique_suffix()}"

        first_payload = {
            "receiver_wallet_number": receiver_wallet[
                "wallet_number"
            ],
            "asset": WalletAsset.COINS.value,
            "amount": 500,
            "idempotency_key": key,
        }

        second_payload = {
            "receiver_wallet_number": receiver_wallet[
                "wallet_number"
            ],
            "asset": WalletAsset.COINS.value,
            "amount": 700,
            "idempotency_key": key,
        }

        first_response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json=first_payload,
        )

        second_response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json=second_payload,
        )

    assert first_response.status_code == 200
    assert second_response.status_code == 400

    assert second_response.json()["detail"] == (
        "Idempotency key was already used "
        "with different transfer parameters"
    )

    sender_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    assert sender_after.coins_balance == 1500
    assert receiver_after.coins_balance == 500


async def test_idempotency_key_rejects_different_asset(
    user_token,
):
    """The same idempotency key cannot switch between assets."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="idempotency_asset_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            points=1000,
            coins=1000,
        )

        key = f"asset-key-{unique_suffix()}"

        first_response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.POINTS.value,
                "amount": 100,
                "idempotency_key": key,
            },
        )

        second_response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 100,
                "idempotency_key": key,
            },
        )

    assert first_response.status_code == 200
    assert second_response.status_code == 400

    assert second_response.json()["detail"] == (
        "Idempotency key was already used "
        "with different transfer parameters"
    )


async def test_idempotency_key_rejects_different_receiver(
    user_token,
):
    """The same idempotency key cannot be reused for another receiver."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_one_token, _ = await register_user(
            client,
            prefix="receiver_one",
        )

        receiver_two_token, _ = await register_user(
            client,
            prefix="receiver_two",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_one_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_one_token}",
            },
        )

        receiver_two_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_two_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_one = receiver_one_response.json()
        receiver_two = receiver_two_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=2000,
        )

        key = f"receiver-key-{unique_suffix()}"

        first_response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_one[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 200,
                "idempotency_key": key,
            },
        )

        second_response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_two[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 200,
                "idempotency_key": key,
            },
        )

    assert first_response.status_code == 200
    assert second_response.status_code == 400

    assert second_response.json()["detail"] == (
        "Idempotency key was already used "
        "with a different receiver wallet"
    )


# ============================================================
# Ledger integrity
# ============================================================


async def test_successful_transfer_creates_two_ledger_entries(
    user_token,
):
    """
    A successful transfer must create exactly two confirmed
    ledger entries: OUT for sender and IN for receiver.
    """

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="ledger_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            points=1000,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.POINTS.value,
                "amount": 350,
                "description": "Ledger QA",
                "extra_data": {
                    "source": "qa",
                    "test": True,
                },
            },
        )

    assert response.status_code == 200

    transfer_data = response.json()
    transfer_id = transfer_data["id"]

    sender_transactions = await get_wallet_transactions(
        sender_wallet["wallet_number"]
    )

    receiver_transactions = await get_wallet_transactions(
        receiver_wallet["wallet_number"]
    )

    assert len(sender_transactions) == 1
    assert len(receiver_transactions) == 1

    sender_transaction = sender_transactions[0]
    receiver_transaction = receiver_transactions[0]

    assert sender_transaction.asset == WalletAsset.POINTS
    assert receiver_transaction.asset == WalletAsset.POINTS

    assert sender_transaction.type == WalletTransactionType.TRANSFER
    assert receiver_transaction.type == WalletTransactionType.TRANSFER

    assert (
        sender_transaction.status
        == WalletTransactionStatus.CONFIRMED
    )
    assert (
        receiver_transaction.status
        == WalletTransactionStatus.CONFIRMED
    )

    assert sender_transaction.amount == -350
    assert receiver_transaction.amount == 350

    assert (
        str(sender_transaction.reference_id)
        == transfer_id
    )

    assert (
        str(receiver_transaction.reference_id)
        == transfer_id
    )

    assert sender_transaction.extra_data["direction"] == "OUT"
    assert receiver_transaction.extra_data["direction"] == "IN"


async def test_idempotent_retry_does_not_create_duplicate_ledger_entries(
    user_token,
):
    """A repeated idempotent request must not duplicate ledger entries."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="ledger_idempotency_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=1000,
        )

        key = f"ledger-key-{unique_suffix()}"

        payload = {
            "receiver_wallet_number": receiver_wallet[
                "wallet_number"
            ],
            "asset": WalletAsset.COINS.value,
            "amount": 250,
            "idempotency_key": key,
        }

        first = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json=payload,
        )

        second = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json=payload,
        )

    assert first.status_code == 200
    assert second.status_code == 200

    sender_transactions = await get_wallet_transactions(
        sender_wallet["wallet_number"]
    )

    receiver_transactions = await get_wallet_transactions(
        receiver_wallet["wallet_number"]
    )

    assert len(sender_transactions) == 1
    assert len(receiver_transactions) == 1


# ============================================================
# Transaction endpoint
# ============================================================


async def test_transaction_endpoint_returns_transfer_entries(
    user_token,
):
    """GET /wallet/transactions must expose transfer ledger entries."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="history_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=1000,
        )

        transfer_response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 125,
            },
        )

        assert transfer_response.status_code == 200

        history_response = await client.get(
            "/api/v1/wallet/transactions",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

    assert history_response.status_code == 200

    history = history_response.json()

    assert len(history) == 1

    transaction = history[0]

    assert transaction["asset"] == WalletAsset.COINS.value
    assert transaction["type"] == WalletTransactionType.TRANSFER.value
    assert (
        transaction["status"]
        == WalletTransactionStatus.CONFIRMED.value
    )
    assert transaction["amount"] == -125
    assert transaction["reference_type"] == "wallet_transfer"


async def test_transaction_status_filter(
    user_token,
):
    """Transaction status filtering must be accepted by the API."""

    token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        response = await client.get(
            "/api/v1/wallet/transactions"
            "?status=CONFIRMED",
            headers={
                "Authorization": f"Bearer {token}",
            },
        )

    assert response.status_code == 200
    assert isinstance(response.json(), list)


# ============================================================
# Atomicity / consistency
# ============================================================


async def test_failed_transfer_does_not_change_balances(
    user_token,
):
    """
    A rejected transfer must leave both wallets untouched.
    """

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="atomic_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=100,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 101,
            },
        )

    assert response.status_code == 400

    sender_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    assert sender_after.coins_balance == 100
    assert receiver_after.coins_balance == 0

    sender_transactions = await get_wallet_transactions(
        sender_wallet["wallet_number"]
    )

    receiver_transactions = await get_wallet_transactions(
        receiver_wallet["wallet_number"]
    )

    assert sender_transactions == []
    assert receiver_transactions == []


async def test_transfer_preserves_other_asset_balance(
    user_token,
):
    """A points transfer must not affect coins, and vice versa."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="asset_isolation_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            points=1000,
            coins=500,
        )

        await set_wallet_balances(
            receiver_wallet["wallet_number"],
            points=100,
            coins=200,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.POINTS.value,
                "amount": 300,
            },
        )

    assert response.status_code == 200

    sender_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    assert sender_after.points_balance == 700
    assert receiver_after.points_balance == 400

    assert sender_after.coins_balance == 500
    assert receiver_after.coins_balance == 200


# ============================================================
# Wallet number validation
# ============================================================


async def test_transfer_rejects_empty_wallet_number(
    user_token,
):
    """Blank receiver wallet numbers must be rejected."""

    token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {token}",
            },
            json={
                "receiver_wallet_number": "",
                "asset": WalletAsset.COINS.value,
                "amount": 10,
            },
        )

    assert response.status_code == 422


async def test_transfer_rejects_wallet_number_over_max_length(
    user_token,
):
    """Wallet numbers longer than 12 characters must be rejected."""

    token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {token}",
            },
            json={
                "receiver_wallet_number": "W123456789012",
                "asset": WalletAsset.COINS.value,
                "amount": 10,
            },
        )

    assert response.status_code == 422


# ============================================================
# Idempotency input validation
# ============================================================


async def test_empty_idempotency_key_is_rejected(
    user_token,
):
    """An explicitly empty idempotency key must be rejected."""

    token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="empty_key_receiver",
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        receiver_wallet = receiver_response.json()

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 10,
                "idempotency_key": "   ",
            },
        )

    assert response.status_code == 400
    assert response.json()["detail"] == (
        "Idempotency key cannot be empty"
    )


async def test_idempotency_key_over_max_length_is_rejected(
    user_token,
):
    """Idempotency keys longer than 100 characters must fail validation."""

    token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="long_key_receiver",
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        receiver_wallet = receiver_response.json()

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 10,
                "idempotency_key": "x" * 101,
            },
        )

    assert response.status_code == 422


# ============================================================
# Transfer response persistence
# ============================================================


async def test_transfer_is_persisted_as_confirmed(
    user_token,
):
    """Successful API transfers must be persisted as CONFIRMED."""

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="persisted_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=1000,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 400,
                "idempotency_key": (
                    f"persist-{unique_suffix()}"
                ),
            },
        )

    assert response.status_code == 200

    data = response.json()

    transfer = await get_transfer_by_id(
        data["id"]
    )

    assert transfer.status == WalletTransferStatus.CONFIRMED
    assert transfer.amount == 400
    assert transfer.asset == WalletAsset.COINS
    assert transfer.completed_at is not None


# ============================================================
# Balance conservation
# ============================================================


async def test_points_transfer_preserves_total_supply(
    user_token,
):
    """
    A transfer must conserve total points between the two wallets.
    """

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="supply_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            points=7000,
        )

        await set_wallet_balances(
            receiver_wallet["wallet_number"],
            points=3000,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.POINTS.value,
                "amount": 1250,
            },
        )

    assert response.status_code == 200

    sender_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    total_after = (
        sender_after.points_balance
        + receiver_after.points_balance
    )

    assert total_after == 10000


async def test_coins_transfer_preserves_total_supply(
    user_token,
):
    """
    A transfer must conserve total coins between the two wallets.
    """

    sender_token, _ = user_token

    async with AsyncClient(
        app=app,
        base_url="http://test",
    ) as client:
        receiver_token, _ = await register_user(
            client,
            prefix="coin_supply_receiver",
        )

        sender_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
        )

        receiver_response = await client.get(
            "/api/v1/wallet",
            headers={
                "Authorization": f"Bearer {receiver_token}",
            },
        )

        sender_wallet = sender_response.json()
        receiver_wallet = receiver_response.json()

        await set_wallet_balances(
            sender_wallet["wallet_number"],
            coins=9000,
        )

        await set_wallet_balances(
            receiver_wallet["wallet_number"],
            coins=1000,
        )

        response = await client.post(
            "/api/v1/wallet/transfer",
            headers={
                "Authorization": f"Bearer {sender_token}",
            },
            json={
                "receiver_wallet_number": receiver_wallet[
                    "wallet_number"
                ],
                "asset": WalletAsset.COINS.value,
                "amount": 2750,
            },
        )

    assert response.status_code == 200

    sender_after = await get_wallet_from_db(
        sender_wallet["wallet_number"]
    )

    receiver_after = await get_wallet_from_db(
        receiver_wallet["wallet_number"]
    )

    total_after = (
        sender_after.coins_balance
        + receiver_after.coins_balance
    )

    assert total_after == 10000
