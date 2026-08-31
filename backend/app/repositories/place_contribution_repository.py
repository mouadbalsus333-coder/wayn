"""Repository for place_contributions table operations."""

from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.place_contribution import (
    PlaceContribution,
    PlaceContributionStatus,
    PlaceContributionType,
)


class PlaceContributionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_contribution(
        self,
        contribution_id: UUID | str,
    ) -> PlaceContribution | None:
        result = await self.session.execute(
            select(PlaceContribution).where(
                PlaceContribution.id == str(contribution_id),
            )
        )

        return result.scalar_one_or_none()

    async def count_user_contributions(
        self,
        user_id: UUID | str,
        *,
        status: PlaceContributionStatus | None = None,
    ) -> int:
        conditions = [
            PlaceContribution.user_id == str(user_id),
        ]

        if status is not None:
            conditions.append(
                PlaceContribution.status == status,
            )

        result = await self.session.execute(
            select(func.count())
            .select_from(PlaceContribution)
            .where(*conditions)
        )

        return result.scalar_one()

    async def list_user_contributions(
        self,
        user_id: UUID | str,
        *,
        status: PlaceContributionStatus | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[PlaceContribution], int]:
        conditions = [
            PlaceContribution.user_id == str(user_id),
        ]

        if status is not None:
            conditions.append(
                PlaceContribution.status == status,
            )

        count_query = (
            select(func.count())
            .select_from(PlaceContribution)
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        query = (
            select(PlaceContribution)
            .where(*conditions)
            .order_by(
                PlaceContribution.created_at.desc(),
            )
            .offset(offset)
            .limit(limit)
        )

        result = await self.session.execute(query)

        return result.scalars().all(), total

    async def list_pending_user_contributions(
        self,
        user_id: UUID | str,
        *,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[PlaceContribution], int]:
        return await self.list_user_contributions(
            user_id,
            status=PlaceContributionStatus.PENDING,
            offset=offset,
            limit=limit,
        )

    async def list_admin_contributions(
        self,
        *,
        status: PlaceContributionStatus | None = None,
        contribution_type: PlaceContributionType | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[PlaceContribution], int]:
        conditions = []

        if status is not None:
            conditions.append(
                PlaceContribution.status == status,
            )

        if contribution_type is not None:
            conditions.append(
                PlaceContribution.type == contribution_type,
            )

        count_query = (
            select(func.count())
            .select_from(PlaceContribution)
            .where(*conditions)
        )

        total = (
            await self.session.execute(count_query)
        ).scalar_one()

        query = (
            select(PlaceContribution)
            .where(*conditions)
            .order_by(
                PlaceContribution.created_at.desc(),
            )
            .offset(offset)
            .limit(limit)
        )

        result = await self.session.execute(query)

        return result.scalars().all(), total

    async def create_contribution(
        self,
        contribution: PlaceContribution,
    ) -> PlaceContribution:
        self.session.add(contribution)

        await self.session.flush()

        return contribution

    async def update_contribution(
        self,
        contribution: PlaceContribution,
    ) -> PlaceContribution:
        await self.session.flush()

        return contribution

    async def delete_contribution(
        self,
        contribution: PlaceContribution,
    ) -> None:
        await self.session.delete(contribution)

        await self.session.flush()