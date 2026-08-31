"""Repository for user_verification_codes table operations."""

from datetime import datetime
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_verification_code import UserVerificationCode


class UserVerificationCodeRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        user_id: UUID,
        purpose: str,
        code_hash: str,
        expires_at: datetime,
    ) -> UserVerificationCode:
        verification_code = UserVerificationCode(
            user_id=user_id,
            purpose=purpose,
            code_hash=code_hash,
            expires_at=expires_at,
        )

        self.session.add(verification_code)
        await self.session.commit()
        await self.session.refresh(verification_code)

        return verification_code

    async def get_latest_active(
        self,
        *,
        user_id: UUID,
        purpose: str,
        now: datetime,
    ) -> UserVerificationCode | None:
        result = await self.session.execute(
            select(UserVerificationCode)
            .where(
                UserVerificationCode.user_id == user_id,
                UserVerificationCode.purpose == purpose,
                UserVerificationCode.used_at.is_(None),
                UserVerificationCode.expires_at > now,
            )
            .order_by(
                UserVerificationCode.created_at.desc(),
            )
            .limit(1)
        )

        return result.scalar_one_or_none()

    async def get_by_id(
        self,
        code_id: int,
    ) -> UserVerificationCode | None:
        result = await self.session.execute(
            select(UserVerificationCode).where(
                UserVerificationCode.id == code_id,
            )
        )

        return result.scalar_one_or_none()

    async def invalidate_active_codes(
        self,
        *,
        user_id: UUID,
        purpose: str,
        now: datetime,
    ) -> None:
        await self.session.execute(
            delete(UserVerificationCode).where(
                UserVerificationCode.user_id == user_id,
                UserVerificationCode.purpose == purpose,
                UserVerificationCode.used_at.is_(None),
                UserVerificationCode.expires_at > now,
            )
        )

        await self.session.commit()

    async def mark_used(
        self,
        verification_code: UserVerificationCode,
        *,
        used_at: datetime,
    ) -> None:
        verification_code.used_at = used_at

        await self.session.commit()
        await self.session.refresh(verification_code)

    async def increment_attempts(
        self,
        verification_code: UserVerificationCode,
    ) -> None:
        verification_code.attempts += 1

        await self.session.commit()
        await self.session.refresh(verification_code)