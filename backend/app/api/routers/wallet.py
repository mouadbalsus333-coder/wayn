"""Wallet API routes."""

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field

from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.models.user import User
from app.models.wallet_transfer import WalletTransfer, WalletTransferStatus
from app.models.wallet_transaction import (
    WalletAsset,
    WalletTransactionStatus,
    WalletTransactionType,
)
from app.services.wallet.service import WalletService


router = APIRouter(
    prefix="/wallet",
    tags=["Wallet"],
)


# ============================================================
# Wallet response
# ============================================================

class WalletResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    wallet_number: str
    points_balance: int
    coins_balance: int


# ============================================================
# Wallet transaction response
# ============================================================

class WalletTransactionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    wallet_id: UUID
    asset: WalletAsset
    type: WalletTransactionType
    status: WalletTransactionStatus
    amount: int
    description: str | None
    reference_type: str | None
    reference_id: UUID | None
    extra_data: dict
    created_at: datetime


# ============================================================
# Wallet transfer request
# ============================================================

class WalletTransferRequest(BaseModel):
    receiver_wallet_number: str = Field(
        min_length=1,
        max_length=12,
    )
    asset: WalletAsset
    amount: int = Field(
        gt=0,
    )
    description: str | None = Field(
        default=None,
        max_length=1000,
    )
    extra_data: dict | None = None
    idempotency_key: str | None = Field(
        default=None,
        max_length=100,
    )


# ============================================================
# Wallet transfer response
# ============================================================

class WalletTransferResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    sender_wallet_id: UUID
    receiver_wallet_id: UUID
    asset: WalletAsset
    amount: int
    status: WalletTransferStatus
    description: str | None
    created_at: datetime
    completed_at: datetime | None


# ============================================================
# Get my wallet
# ============================================================

@router.get(
    "",
    response_model=WalletResponse,
    status_code=status.HTTP_200_OK,
)
async def get_my_wallet(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WalletResponse:
    service = WalletService(session)

    wallet = await service.get_or_create_wallet(
        current_user.id
    )

    return WalletResponse.model_validate(wallet)


# ============================================================
# Transfer between wallets
# ============================================================

@router.post(
    "/transfer",
    response_model=WalletTransferResponse,
    status_code=status.HTTP_200_OK,
)
async def transfer_wallet(
    payload: WalletTransferRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WalletTransferResponse:
    service = WalletService(session)

    try:
        transfer = await service.transfer(
            sender_user_id=current_user.id,
            receiver_wallet_number=payload.receiver_wallet_number,
            asset=payload.asset,
            amount=payload.amount,
            description=payload.description,
            extra_data=payload.extra_data,
            idempotency_key=payload.idempotency_key,
        )

    except ValueError as exc:
        message = str(exc)

        if message in {
            "Sender wallet not found",
            "Receiver wallet not found",
        }:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message,
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc

    return WalletTransferResponse.model_validate(transfer)


# ============================================================
# Get my wallet transactions
# ============================================================

@router.get(
    "/transactions",
    response_model=list[WalletTransactionResponse],
    status_code=status.HTTP_200_OK,
)
async def get_my_wallet_transactions(
    limit: int = Query(
        default=50,
        ge=1,
        le=100,
    ),
    offset: int = Query(
        default=0,
        ge=0,
    ),
    transaction_status: WalletTransactionStatus | None = Query(
        default=None,
        alias="status",
    ),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[WalletTransactionResponse]:
    service = WalletService(session)

    transactions = await service.list_transactions(
        current_user.id,
        limit=limit,
        offset=offset,
        status=transaction_status,
    )

    return [
        WalletTransactionResponse.model_validate(transaction)
        for transaction in transactions
    ]