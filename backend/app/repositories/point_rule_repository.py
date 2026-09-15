"""Repository for point_rules table operations."""

import sqlalchemy as sa
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.point_rule import PointRule


class PointRuleRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_rule(self, rule_id: int) -> PointRule | None:
        result = await self.session.execute(
            select(PointRule).where(PointRule.id == rule_id)
        )
        return result.scalar_one_or_none()

    async def get_rule_by_key(self, action_key: str) -> PointRule | None:
        result = await self.session.execute(
            select(PointRule).where(PointRule.action_key == action_key)
        )
        return result.scalar_one_or_none()

    async def list_rules(
        self,
        *,
        active_only: bool = False,
    ) -> list[PointRule]:
        query = select(PointRule).order_by(PointRule.id)

        if active_only:
            query = query.where(PointRule.is_active == True)

        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def create_rule(self, rule: PointRule) -> PointRule:
        self.session.add(rule)
        await self.session.flush()
        return rule

    async def flush(self) -> None:
        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()
