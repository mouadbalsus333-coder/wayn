"""Admin wallet recharge API routes."""

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, ConfigDict, Field

from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import AdminUser, require_permission
from app.core.database import get_session
from app.models.wallet_admin_recharge import WalletAdminRechargeStatus
from app.models.wallet_transfer import WalletTransferStatus
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


# ============================================================
# Wallet Reports (aggregated statistics)
# ============================================================

class WalletReportsResponse(BaseModel):
    """Aggregated wallet statistics for a given time period."""
    model_config = ConfigDict(from_attributes=True)

    period_start: datetime | None
    period_end: datetime | None
    total_recharges: int
    total_recharge_amount: int
    confirmed_recharges: int
    failed_recharges: int
    total_transfers: int
    confirmed_transfers: int
    failed_transfers: int
    total_transfer_amount: int


@router.get(
    "/reports",
    response_model=WalletReportsResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[
        Depends(require_permission("wallet.read")),
    ],
)
async def get_wallet_reports(
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    session: AsyncSession = Depends(get_session),
) -> WalletReportsResponse:
    """
    Aggregated wallet statistics for reports.

    Supports date filtering for daily/weekly/monthly/yearly views.
    """
    from sqlalchemy import func, select

    from app.models.wallet_admin_recharge import WalletAdminRecharge, WalletAdminRechargeStatus
    from app.models.wallet_transfer import WalletTransfer, WalletTransferStatus

    # Build date conditions
    recharge_conditions = []
    transfer_conditions = []

    if created_from is not None:
        recharge_conditions.append(WalletAdminRecharge.created_at >= created_from)
        transfer_conditions.append(WalletTransfer.created_at >= created_from)
    if created_to is not None:
        recharge_conditions.append(WalletAdminRecharge.created_at <= created_to)
        transfer_conditions.append(WalletTransfer.created_at <= created_to)

    # Recharge stats
    recharge_total_query = select(func.count()).select_from(WalletAdminRecharge)
    if recharge_conditions:
        recharge_total_query = recharge_total_query.where(*recharge_conditions)
    total_recharges = (await session.execute(recharge_total_query)).scalar_one()

    recharge_amount_query = select(func.coalesce(func.sum(WalletAdminRecharge.amount), 0)).select_from(WalletAdminRecharge)
    if recharge_conditions:
        recharge_amount_query = recharge_amount_query.where(*recharge_conditions)
    recharge_amount_query = recharge_amount_query.where(
        WalletAdminRecharge.status == WalletAdminRechargeStatus.CONFIRMED
    )
    total_recharge_amount = (await session.execute(recharge_amount_query)).scalar_one()

    confirmed_query = select(func.count()).select_from(WalletAdminRecharge).where(
        WalletAdminRecharge.status == WalletAdminRechargeStatus.CONFIRMED
    )
    if recharge_conditions:
        confirmed_query = confirmed_query.where(*recharge_conditions)
    confirmed_recharges = (await session.execute(confirmed_query)).scalar_one()

    failed_query = select(func.count()).select_from(WalletAdminRecharge).where(
        WalletAdminRecharge.status == WalletAdminRechargeStatus.FAILED
    )
    if recharge_conditions:
        failed_query = failed_query.where(*recharge_conditions)
    failed_recharges = (await session.execute(failed_query)).scalar_one()

    # Transfer stats
    transfer_total_query = select(func.count()).select_from(WalletTransfer)
    if transfer_conditions:
        transfer_total_query = transfer_total_query.where(*transfer_conditions)
    total_transfers = (await session.execute(transfer_total_query)).scalar_one()

    transfer_confirmed_query = select(func.count()).select_from(WalletTransfer).where(
        WalletTransfer.status == WalletTransferStatus.CONFIRMED
    )
    if transfer_conditions:
        transfer_confirmed_query = transfer_confirmed_query.where(*transfer_conditions)
    confirmed_transfers = (await session.execute(transfer_confirmed_query)).scalar_one()

    transfer_failed_query = select(func.count()).select_from(WalletTransfer).where(
        WalletTransfer.status == WalletTransferStatus.FAILED
    )
    if transfer_conditions:
        transfer_failed_query = transfer_failed_query.where(*transfer_conditions)
    failed_transfers = (await session.execute(transfer_failed_query)).scalar_one()

    transfer_amount_query = select(func.coalesce(func.sum(WalletTransfer.amount), 0)).select_from(WalletTransfer).where(
        WalletTransfer.status == WalletTransferStatus.CONFIRMED
    )
    if transfer_conditions:
        transfer_amount_query = transfer_amount_query.where(*transfer_conditions)
    total_transfer_amount = (await session.execute(transfer_amount_query)).scalar_one()

    return WalletReportsResponse(
        period_start=created_from,
        period_end=created_to,
        total_recharges=total_recharges,
        total_recharge_amount=int(total_recharge_amount),
        confirmed_recharges=confirmed_recharges,
        failed_recharges=failed_recharges,
        total_transfers=total_transfers,
        confirmed_transfers=confirmed_transfers,
        failed_transfers=failed_transfers,
        total_transfer_amount=int(total_transfer_amount),
    )


# ============================================================
# Wallet Transfers (admin monitoring)
# ============================================================

class WalletTransferItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    sender_wallet_id: UUID
    receiver_wallet_id: UUID
    sender_wallet_number: str | None
    receiver_wallet_number: str | None
    sender_name: str | None
    receiver_name: str | None
    asset: str
    amount: int
    status: WalletTransferStatus
    description: str | None
    created_at: datetime
    completed_at: datetime | None


class WalletTransferListResponse(BaseModel):
    items: list[WalletTransferItem]
    total: int
    offset: int
    limit: int


@router.get(
    "/transfers",
    response_model=WalletTransferListResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[
        Depends(require_permission("wallet.transactions")),
    ],
)
async def list_transfers(
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    transfer_status: WalletTransferStatus | None = Query(default=None, alias="status"),
    search: str | None = Query(default=None, max_length=100),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> WalletTransferListResponse:
    """
    List wallet transfers for admin monitoring.

    Supports filtering by date range, status, and search by wallet number.
    """
    from sqlalchemy import func, select
    from sqlalchemy.orm import selectinload

    from app.models.wallet_transfer import WalletTransfer
    from app.models.wallet import UserWallet
    from app.models.user import User

    # Build query with joins for wallet numbers and user names
    query = (
        select(WalletTransfer)
        .options(
            selectinload(WalletTransfer.sender_wallet).selectinload(UserWallet.user),
            selectinload(WalletTransfer.receiver_wallet).selectinload(UserWallet.user),
        )
    )

    # Apply filters
    if created_from is not None:
        query = query.where(WalletTransfer.created_at >= created_from)
    if created_to is not None:
        query = query.where(WalletTransfer.created_at <= created_to)
    if transfer_status is not None:
        query = query.where(WalletTransfer.status == transfer_status)

    # Count total
    count_query = select(func.count()).select_from(WalletTransfer)
    if created_from is not None:
        count_query = count_query.where(WalletTransfer.created_at >= created_from)
    if created_to is not None:
        count_query = count_query.where(WalletTransfer.created_at <= created_to)
    if transfer_status is not None:
        count_query = count_query.where(WalletTransfer.status == transfer_status)

    total = (await session.execute(count_query)).scalar_one()

    # Apply ordering and pagination
    query = (
        query
        .order_by(WalletTransfer.created_at.desc())
        .offset(offset)
        .limit(limit)
    )

    result = await session.execute(query)
    transfers = result.scalars().all()

    items = []
    for t in transfers:
        sender_wallet = t.sender_wallet
        receiver_wallet = t.receiver_wallet

        items.append(WalletTransferItem(
            id=t.id,
            sender_wallet_id=t.sender_wallet_id,
            receiver_wallet_id=t.receiver_wallet_id,
            sender_wallet_number=sender_wallet.wallet_number if sender_wallet else None,
            receiver_wallet_number=receiver_wallet.wallet_number if receiver_wallet else None,
            sender_name=sender_wallet.user.full_name if sender_wallet and sender_wallet.user else None,
            receiver_name=receiver_wallet.user.full_name if receiver_wallet and receiver_wallet.user else None,
            asset=t.asset.value,
            amount=t.amount,
            status=t.status,
            description=t.description,
            created_at=t.created_at,
            completed_at=t.completed_at,
        ))

    return WalletTransferListResponse(
        items=items,
        total=total,
        offset=offset,
        limit=limit,
    )
