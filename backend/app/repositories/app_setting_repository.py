"""Application setting repository."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.app_setting import AppSetting


STORE_ADS_ROTATION_SECONDS_KEY = "store_ads_rotation_seconds"


class AppSettingRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_value(self, key: str) -> str | None:
        result = await self.session.execute(
            select(AppSetting.value).where(AppSetting.key == key)
        )

        return result.scalar_one_or_none()

    async def set_value(
        self,
        key: str,
        value: str,
        description: str | None = None,
    ) -> str:
        result = await self.session.execute(
            select(AppSetting).where(AppSetting.key == key)
        )

        setting = result.scalar_one_or_none()

        if setting is None:
            setting = AppSetting(key=key, value=value, description=description)
            self.session.add(setting)
        else:
            setting.value = value
            if description is not None:
                setting.description = description

        await self.session.commit()
        return setting.value
