"""Admin wallet recharge API routes."""

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, ConfigDict, Field

from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import AdminUser, require_permission
from app.core.database import get_session
from app.models.wallet_admin_recharge import WalletAdminRechargeStatus
from app.services.wallet.admin_recharge_service import AdminRechargeService


router = APIRouter(
    prefix="/admin/wallet",
    tags=["Admin Wallet"],
)


# ============================================================
# Lookup response
# ============================================================

class WalletLookupResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    wallet_id: UUID
    wallet_number: str
    full_name: str
    username: str
    phone: str | None
    coins_balance: int
    wallet_status: str | None = None
    is_active: bool
    is_verified: bool


# ============================================================
# Recharge request / response
# ============================================================

class WalletRechargeRequest(BaseModel):
    target_user_id: UUID
    amount: int = Field(
        gt=0,
    )
    note: str | None = Field(
        default=None,
        max_length=1000,
    )
    idempotency_key: str | None = Field(
        default=None,
        max_length=100,
    )


class WalletRechargeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    recharge_id: UUID
    transaction_id: UUID
    user_id: UUID
    wallet_id: UUID
    wallet_number: str
    amount: int
    balance_before: int
    balance_after: int
    status: WalletAdminRechargeStatus
    admin_id: int
    admin_email: str
    created_at: datetime


def _recharge_response(
    recharge,
) -> WalletRechargeResponse:
    return WalletRechargeResponse(
        recharge_id=recharge.id,
        transaction_id=recharge.transaction_id,
        user_id=recharge.user_id,
        wallet_id=recharge.wallet_id,
        wallet_number=recharge.wallet_number,
        amount=recharge.amount,
        balance_before=recharge.balance_before,
        balance_after=recharge.balance_after,
        status=recharge.status,
        admin_id=recharge.admin_id,
        admin_email=recharge.admin_email,
        created_at=recharge.created_at,
    )


# ============================================================
# Lookup (confirmation screen data)
# ============================================================

@router.get(
    "/lookup",
    response_model=WalletLookupResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[
        Depends(require_permission("wallet.read")),
    ],
)
async def lookup_wallet(
    wallet_number: str | None = Query(
        default=None,
        max_length=12,
    ),
    user_id: UUID | None = Query(
        default=None,
    ),
    session: AsyncSession = Depends(get_session),
) -> WalletLookupResponse:
    """
    Look up a wallet by wallet_number OR user_id (exactly one).
    Returns the account data shown on the recharge confirmation
    screen. Read-only.
    """
    service = AdminRechargeService(session)

    try:
        found = await service.lookup_wallet(
            wallet_number=wallet_number,
            user_id=user_id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    if found is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        )

    # wallet_status is a WalletStatus enum from the model; expose it
    # as its plain value for the client.
    found["wallet_status"] = (
        found["wallet_status"].value
        if found["wallet_status"] is not None
        else None
    )

    return WalletLookupResponse(**found)


# ============================================================
# Recharge
# ============================================================

@router.post(
    "/recharge",
    response_model=WalletRechargeResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[
        Depends(require_permission("wallet.recharge")),
    ],
)
async def recharge_wallet(
    payload: WalletRechargeRequest,
    request: Request,
    current_admin: AdminUser = Depends(
        require_permission("wallet.recharge")
    ),
    session: AsyncSession = Depends(get_session),
) -> WalletRechargeResponse:
    """
    Recharge a user's wallet with Coins.

    Balances are computed by the backend only. The current admin,
    IP address, and User-Agent are taken from the authenticated
    request, never from the body.
    """
    service = AdminRechargeService(session)

    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    try:
        recharge = await service.recharge_wallet(
            target_user_id=payload.target_user_id,
            amount=payload.amount,
            admin=current_admin,
            note=payload.note,
            idempotency_key=payload.idempotency_key,
            ip_address=ip_address,
            user_agent=user_agent,
        )
    except ValueError as exc:
        message = str(exc)

        if message in {
            "User wallet not found",
            "User not found",
        }:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message,
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from exc

    return _recharge_response(recharge)


# ============================================================
# Statistics (declared before /recharges/{recharge_id} so FastAPI
# does not interpret "stats" as a recharge id)
# ============================================================

class WalletRechargeStatsResponse(BaseModel):
    total_operations: int
    total_coins_recharged: int
    confirmed_count: int
    failed_count: int


@router.get(
    "/recharges/stats",
    response_model=WalletRechargeStatsResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[
        Depends(require_permission("wallet.read")),
    ],
)
async def get_recharge_stats(
    created_from: datetime | None = Query(
        default=None,
    ),
    created_to: datetime | None = Query(
        default=None,
    ),
    session: AsyncSession = Depends(get_session),
) -> WalletRechargeStatsResponse:
    """Aggregate admin recharge statistics."""
    service = AdminRechargeService(session)

    stats = await service.get_stats(
        created_from=created_from,
        created_to=created_to,
    )

    return WalletRechargeStatsResponse(**stats)


# ============================================================
# Recharge log (paginated + filters)
# ============================================================

class WalletRechargeListResponse(BaseModel):
    items: list[WalletRechargeResponse]
    total: int
    offset: int
    limit: int


@router.get(
    "/recharges",
    response_model=WalletRechargeListResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[
        Depends(require_permission("wallet.read")),
    ],
)
async def list_recharges(
    wallet_number: str | None = Query(
        default=None,
        max_length=12,
    ),
    user_id: UUID | None = Query(
        default=None,
    ),
    admin_id: int | None = Query(
        default=None,
    ),
    recharge_status: WalletAdminRechargeStatus | None = Query(
        default=None,
        alias="status",
    ),
    created_from: datetime | None = Query(
        default=None,
    ),
    created_to: datetime | None = Query(
        default=None,
    ),
    search: str | None = Query(
        default=None,
        max_length=100,
    ),
    offset: int = Query(
        default=0,
        ge=0,
    ),
    limit: int = Query(
        default=20,
        ge=1,
        le=100,
    ),
    session: AsyncSession = Depends(get_session),
) -> WalletRechargeListResponse:
    """
    List admin recharge operations, newest first, with filters and
    pagination. User history is covered by passing user_id here.
    """
    service = AdminRechargeService(session)

    items, total = await service.list_recharges(
        wallet_number=wallet_number,
        user_id=user_id,
        admin_id=admin_id,
        status=recharge_status,
        created_from=created_from,
        created_to=created_to,
        search=search,
        offset=offset,
        limit=limit,
    )

    return WalletRechargeListResponse(
        items=[_recharge_response(item) for item in items],
        total=total,
        offset=offset,
        limit=limit,
    )


# ============================================================
# Recharge details (declared after /recharges/stats)
# ============================================================

class WalletRechargeDetailUser(BaseModel):
    id: UUID
    full_name: str
    username: str
    phone: str | None


class WalletRechargeDetailAdmin(BaseModel):
    id: int
    email: str
    full_name: str


class WalletRechargeDetailResponse(WalletRechargeResponse):
    note: str | None
    idempotency_key: str | None
    ip_address: str | None
    user_agent: str | None
    user: WalletRechargeDetailUser
    admin: WalletRechargeDetailAdmin


@router.get(
    "/recharges/{recharge_id}",
    response_model=WalletRechargeDetailResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[
        Depends(require_permission("wallet.read")),
    ],
)
async def get_recharge(
    recharge_id: UUID,
    session: AsyncSession = Depends(get_session),
) -> WalletRechargeDetailResponse:
    """Full details of one admin recharge operation."""
    service = AdminRechargeService(session)

    recharge = await service.get_recharge(recharge_id)

    if recharge is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recharge not found",
        )

    return WalletRechargeDetailResponse(
        recharge_id=recharge.id,
        transaction_id=recharge.transaction_id,
        user_id=recharge.user_id,
        wallet_id=recharge.wallet_id,
        wallet_number=recharge.wallet_number,
        amount=recharge.amount,
        balance_before=recharge.balance_before,
        balance_after=recharge.balance_after,
        status=recharge.status,
        admin_id=recharge.admin_id,
        admin_email=recharge.admin_email,
        created_at=recharge.created_at,
        note=recharge.note,
        idempotency_key=recharge.idempotency_key,
        ip_address=recharge.ip_address,
        user_agent=recharge.user_agent,
        user=WalletRechargeDetailUser(
            id=recharge.user.id,
            full_name=recharge.user.full_name,
            username=recharge.user.username,
            phone=recharge.user.phone,
        ),
        admin=WalletRechargeDetailAdmin(
            id=recharge.admin.id,
            email=recharge.admin.email,
            full_name=recharge.admin.full_name,
        ),
    )
