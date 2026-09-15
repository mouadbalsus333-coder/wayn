"""Admin point rules (tasks) API routes."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import require_permission
from app.core.database import get_session
from app.schemas.point_rule import (
    PointRuleCreate,
    PointRuleRead,
    PointRuleUpdate,
)
from app.services.point_rule_service import PointRuleService


router = APIRouter(
    prefix="/admin/point-rules",
    tags=["Admin Points"],
)


@router.get(
    "",
    response_model=list[PointRuleRead],
)
async def list_point_rules(
    admin_user=Depends(require_permission("points.manage")),
    session: AsyncSession = Depends(get_session),
) -> list[PointRuleRead]:
    service = PointRuleService(session)

    rules = await service.list_rules()

    return [PointRuleRead.model_validate(rule) for rule in rules]


@router.post(
    "",
    response_model=PointRuleRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_point_rule(
    data: PointRuleCreate,
    admin_user=Depends(require_permission("points.manage")),
    session: AsyncSession = Depends(get_session),
) -> PointRuleRead:
    service = PointRuleService(session)

    try:
        rule = await service.create_rule(data)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return PointRuleRead.model_validate(rule)


@router.patch(
    "/{rule_id}",
    response_model=PointRuleRead,
)
async def update_point_rule(
    rule_id: int,
    data: PointRuleUpdate,
    admin_user=Depends(require_permission("points.manage")),
    session: AsyncSession = Depends(get_session),
) -> PointRuleRead:
    service = PointRuleService(session)

    rule = await service.get_rule(rule_id)

    if rule is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Point rule not found",
        )

    rule = await service.update_rule(rule, data)

    return PointRuleRead.model_validate(rule)
