"""User points API routes."""

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict

from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.models.user import User
from app.models.user_point_transaction import (
    UserPointTransaction,
    UserPointTransactionStatus,
    UserPointTransactionType,
)
from app.services.user_point.service import UserPointService


router = APIRouter(
    prefix="/points",
    tags=["User Points"],
)


# ============================================================
# Points balance response
# ============================================================

class PointsBalanceResponse(BaseModel):
    user_id: UUID
    points: int


# ============================================================
# Point transaction response
# ============================================================

class PointTransactionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    type: UserPointTransactionType
    status: UserPointTransactionStatus
    amount: int
    balance_after: int
    description: str | None
    reference_type: str | None
    reference_id: UUID | None
    extra_data: dict
    created_at: datetime


# ============================================================
# Get my points balance
# ============================================================

@router.get(
    "",
    response_model=PointsBalanceResponse,
    status_code=status.HTTP_200_OK,
)
async def get_my_points(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> PointsBalanceResponse:
    service = UserPointService(session)

    try:
        points = await service.get_balance(
            current_user.id,
        )

    except ValueError as exc:
        message = str(exc)

        if message == "User not found":
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message,
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc

    return PointsBalanceResponse(
        user_id=current_user.id,
        points=points,
    )


# ============================================================
# Get my point transactions
# ============================================================

@router.get(
    "/transactions",
    response_model=list[PointTransactionResponse],
    status_code=status.HTTP_200_OK,
)
async def get_my_point_transactions(
    limit: int = Query(
        default=50,
        ge=1,
        le=100,
    ),
    offset: int = Query(
        default=0,
        ge=0,
    ),
    transaction_type: UserPointTransactionType | None = Query(
        default=None,
    ),
    transaction_status: UserPointTransactionStatus | None = Query(
        default=None,
        alias="status",
    ),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[PointTransactionResponse]:
    service = UserPointService(session)

    try:
        transactions = await service.list_transactions(
            current_user.id,
            limit=limit,
            offset=offset,
            transaction_type=transaction_type,
            status=transaction_status,
        )

    except ValueError as exc:
        message = str(exc)

        if message == "User not found":
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message,
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc

    return [
        PointTransactionResponse.model_validate(
            transaction,
        )
        for transaction in transactions
    ]