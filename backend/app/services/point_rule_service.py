"""Business logic for point rules (tasks)."""

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.place_contribution import PlaceContributionType
from app.models.point_rule import PointRule
from app.repositories.point_rule_repository import PointRuleRepository
from app.schemas.point_rule import PointRuleCreate, PointRuleUpdate


class PointRuleService:
    """Business logic for configurable point reward tasks."""

    def __init__(self, session: AsyncSession) -> None:
        self.repository = PointRuleRepository(session)

    # ============================================================
    # Mapping: contribution type -> point rule action key
    # ============================================================

    CONTRIBUTION_ACTION_KEYS: dict[PlaceContributionType, str] = {
        PlaceContributionType.CREATE_PLACE: "add_place",
        PlaceContributionType.UPDATE_PLACE: "update_place",
        PlaceContributionType.ADD_IMAGE: "add_image",
        PlaceContributionType.UPDATE_INFORMATION: "update_information",
        PlaceContributionType.VERIFY_PLACE: "verify_place",
    }

    # ============================================================
    # Reads
    # ============================================================

    async def list_rules(self, *, active_only: bool = False) -> list[PointRule]:
        return await self.repository.list_rules(active_only=active_only)

    async def get_rule(self, rule_id: int) -> PointRule | None:
        return await self.repository.get_rule(rule_id)

    async def get_reward_for_contribution_type(
        self,
        contribution_type: PlaceContributionType,
    ) -> int | None:
        """Return the configured reward for a contribution type.

        The rule must be active for its reward to apply; inactive
        rules fall back to the caller's default.
        """

        action_key = self.CONTRIBUTION_ACTION_KEYS.get(contribution_type)

        if action_key is None:
            return None

        rule = await self.repository.get_rule_by_key(action_key)

        if rule is None or not rule.is_active:
            return None

        return rule.points

    # ============================================================
    # Admin mutations
    # ============================================================

    async def create_rule(self, data: PointRuleCreate) -> PointRule:
        existing = await self.repository.get_rule_by_key(data.action_key)

        if existing is not None:
            raise ValueError("A rule with this action key already exists")

        rule = PointRule(
            action_key=data.action_key,
            points=data.points,
            title=data.title,
            description=data.description,
            is_active=data.is_active,
            requires_approval=data.requires_approval,
            limit_per_user=data.limit_per_user,
        )

        rule = await self.repository.create_rule(rule)
        await self.repository.commit()
        return rule

    async def update_rule(self, rule: PointRule, data: PointRuleUpdate) -> PointRule:
        update_data = data.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            setattr(rule, field, value)

        await self.repository.flush()
        await self.repository.commit()
        return rule
