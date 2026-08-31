"""Business logic for place contributions."""

from typing import Any
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.place_contribution import (
    PlaceContribution,
    PlaceContributionStatus,
    PlaceContributionType,
)
from app.models.user_point_transaction import (
    UserPointTransactionType,
)
from app.repositories.place_contribution_repository import (
    PlaceContributionRepository,
)
from app.repositories.place_repository import PlaceRepository
from app.repositories.category_repository import CategoryRepository
from app.schemas.place import PlaceCreate, PlaceUpdate
from app.services.place_service import PlaceService
from app.services.user_point.service import UserPointService


class PlaceContributionService:
    """Business logic for user-generated place contributions."""

    # Points awarded after an approved contribution.
    DEFAULT_POINTS = 10

    def __init__(
        self,
        session: AsyncSession,
    ) -> None:
        self.session = session

        self.contribution_repository = (
            PlaceContributionRepository(session)
        )

        self.place_repository = PlaceRepository(session)

        self.category_repository = CategoryRepository(
            session
        )

        self.place_service = PlaceService(
            self.place_repository,
            self.category_repository,
        )

        self.point_service = UserPointService(session)

    # ============================================================
    # Create contribution
    # ============================================================

    async def create_contribution(
        self,
        *,
        user_id: UUID,
        contribution_type: PlaceContributionType,
        title: str,
        description: str | None,
        payload: dict[str, Any],
        place_id: UUID | str | None = None,
    ) -> PlaceContribution:

        # --------------------------------------------------------
        # Validate contribution type
        # --------------------------------------------------------

        if contribution_type in {
            PlaceContributionType.UPDATE_PLACE,
            PlaceContributionType.ADD_IMAGE,
            PlaceContributionType.UPDATE_INFORMATION,
            PlaceContributionType.VERIFY_PLACE,
        }:
            if place_id is None:
                raise ValueError(
                    "place_id is required for this contribution type"
                )

            place = await self.place_repository.get_place(
                str(place_id)
            )

            if place is None:
                raise ValueError("Place not found")

        # --------------------------------------------------------
        # CREATE_PLACE must not reference an existing place
        # --------------------------------------------------------

        if (
            contribution_type
            == PlaceContributionType.CREATE_PLACE
            and place_id is not None
        ):
            raise ValueError(
                "CREATE_PLACE cannot reference an existing place"
            )

        # --------------------------------------------------------
        # Create contribution
        # --------------------------------------------------------

        contribution = PlaceContribution(
            user_id=user_id,
            place_id=(
                UUID(str(place_id))
                if place_id is not None
                else None
            ),
            type=contribution_type,
            status=PlaceContributionStatus.PENDING,
            title=title,
            description=description,
            payload=payload,
        )

        return await self.contribution_repository.create_contribution(
            contribution
        )

    # ============================================================
    # Get contribution
    # ============================================================

    async def get_contribution(
        self,
        contribution_id: UUID | str,
    ) -> PlaceContribution | None:

        return await self.contribution_repository.get_contribution(
            contribution_id
        )

    # ============================================================
    # User contributions
    # ============================================================

    async def list_user_contributions(
        self,
        user_id: UUID,
        *,
        status: PlaceContributionStatus | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[PlaceContribution], int]:

        return await self.contribution_repository.list_user_contributions(
            user_id,
            status=status,
            offset=offset,
            limit=limit,
        )

    # ============================================================
    # Cancel contribution
    # ============================================================

    async def cancel_contribution(
        self,
        *,
        contribution: PlaceContribution,
        user_id: UUID,
    ) -> PlaceContribution:

        if contribution.user_id != user_id:
            raise ValueError(
                "You can only cancel your own contribution"
            )

        if contribution.status != (
            PlaceContributionStatus.PENDING
        ):
            raise ValueError(
                "Only pending contributions can be cancelled"
            )

        contribution.status = (
            PlaceContributionStatus.CANCELLED
        )

        return await self.contribution_repository.update_contribution(
            contribution
        )

    # ============================================================
    # Admin: list contributions
    # ============================================================

    async def list_admin_contributions(
        self,
        *,
        status: PlaceContributionStatus | None = None,
        contribution_type: PlaceContributionType | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[PlaceContribution], int]:

        return await self.contribution_repository.list_admin_contributions(
            status=status,
            contribution_type=contribution_type,
            offset=offset,
            limit=limit,
        )

    # ============================================================
    # Admin: approve
    # ============================================================

    async def approve_contribution(
        self,
        *,
        contribution: PlaceContribution,
        admin_id: int,
        points: int | None = None,
    ) -> PlaceContribution:

        if contribution.status != (
            PlaceContributionStatus.PENDING
        ):
            raise ValueError(
                "Only pending contributions can be approved"
            )

        if points is None:
            points = self.DEFAULT_POINTS

        if points < 0:
            raise ValueError(
                "Points cannot be negative"
            )

        try:
            # ----------------------------------------------------
            # Apply contribution to the place
            # ----------------------------------------------------

            if contribution.type == (
                PlaceContributionType.CREATE_PLACE
            ):
                await self._apply_create_place(
                    contribution
                )

            elif contribution.type == (
                PlaceContributionType.UPDATE_PLACE
            ):
                await self._apply_update_place(
                    contribution
                )

            elif contribution.type == (
                PlaceContributionType.ADD_IMAGE
            ):
                await self._apply_add_image(
                    contribution
                )

            elif contribution.type == (
                PlaceContributionType.UPDATE_INFORMATION
            ):
                await self._apply_update_information(
                    contribution
                )

            elif contribution.type == (
                PlaceContributionType.VERIFY_PLACE
            ):
                await self._apply_verify_place(
                    contribution
                )

            # ----------------------------------------------------
            # Mark contribution approved
            # ----------------------------------------------------

            contribution.status = (
                PlaceContributionStatus.APPROVED
            )

            contribution.reviewed_by = admin_id

            from datetime import datetime, timezone

            contribution.reviewed_at = datetime.now(
                timezone.utc
            )

            contribution.points_awarded = points

            # ----------------------------------------------------
            # Award points
            # ----------------------------------------------------

            if points > 0:
                await self.point_service.add_points(
                    contribution.user_id,
                    points,
                    transaction_type=(
                        UserPointTransactionType.CONTRIBUTION
                    ),
                    description=(
                        f"Contribution approved: "
                        f"{contribution.title}"
                    ),
                    reference_type="PLACE_CONTRIBUTION",
                    reference_id=contribution.id,
                    admin_id=admin_id,
                )

            await self.contribution_repository.update_contribution(
                contribution
            )

            return contribution

        except Exception:
            await self.session.rollback()
            raise

    # ============================================================
    # Admin: reject
    # ============================================================

    async def reject_contribution(
        self,
        *,
        contribution: PlaceContribution,
        admin_id: int,
        rejection_reason: str,
    ) -> PlaceContribution:

        if contribution.status != (
            PlaceContributionStatus.PENDING
        ):
            raise ValueError(
                "Only pending contributions can be rejected"
            )

        rejection_reason = rejection_reason.strip()

        if not rejection_reason:
            raise ValueError(
                "Rejection reason is required"
            )

        from datetime import datetime, timezone

        contribution.status = (
            PlaceContributionStatus.REJECTED
        )

        contribution.reviewed_by = admin_id

        contribution.reviewed_at = datetime.now(
            timezone.utc
        )

        contribution.rejection_reason = (
            rejection_reason
        )

        contribution.points_awarded = 0

        return await self.contribution_repository.update_contribution(
            contribution
        )

    # ============================================================
    # Apply CREATE_PLACE
    # ============================================================

    async def _apply_create_place(
        self,
        contribution: PlaceContribution,
    ) -> None:

        data = PlaceCreate.model_validate(
            contribution.payload
        )

        place = await self.place_service.create_place(
            data
        )

        contribution.place_id = place.id

    # ============================================================
    # Apply UPDATE_PLACE
    # ============================================================

    async def _apply_update_place(
        self,
        contribution: PlaceContribution,
    ) -> None:

        if contribution.place_id is None:
            raise ValueError(
                "Contribution has no place_id"
            )

        place = await self.place_repository.get_place(
            str(contribution.place_id)
        )

        if place is None:
            raise ValueError(
                "Place not found"
            )

        data = PlaceUpdate.model_validate(
            contribution.payload
        )

        await self.place_service.update_place(
            place,
            data,
        )

    # ============================================================
    # Apply ADD_IMAGE
    # ============================================================

    async def _apply_add_image(
        self,
        contribution: PlaceContribution,
    ) -> None:

        if contribution.place_id is None:
            raise ValueError(
                "Contribution has no place_id"
            )

        place = await self.place_repository.get_place(
            str(contribution.place_id)
        )

        if place is None:
            raise ValueError(
                "Place not found"
            )

        image_url = contribution.payload.get(
            "image_url"
        )

        if not image_url:
            raise ValueError(
                "image_url is required"
            )

        images = list(place.images or [])

        if image_url not in images:
            images.append(image_url)

        place.images = images

        await self.place_repository.update_place(
            place
        )

    # ============================================================
    # Apply UPDATE_INFORMATION
    # ============================================================

    async def _apply_update_information(
        self,
        contribution: PlaceContribution,
    ) -> None:

        if contribution.place_id is None:
            raise ValueError(
                "Contribution has no place_id"
            )

        place = await self.place_repository.get_place(
            str(contribution.place_id)
        )

        if place is None:
            raise ValueError(
                "Place not found"
            )

        data = PlaceUpdate.model_validate(
            contribution.payload
        )

        await self.place_service.update_place(
            place,
            data,
        )

    # ============================================================
    # Apply VERIFY_PLACE
    # ============================================================

    async def _apply_verify_place(
        self,
        contribution: PlaceContribution,
    ) -> None:

        if contribution.place_id is None:
            raise ValueError(
                "Contribution has no place_id"
            )

        place = await self.place_repository.get_place(
            str(contribution.place_id)
        )

        if place is None:
            raise ValueError(
                "Place not found"
            )

        place.verification_status = "VERIFIED"

        await self.place_repository.update_place(
            place
        )