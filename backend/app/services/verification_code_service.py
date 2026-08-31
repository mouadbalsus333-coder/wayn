"""Service for generating and validating user verification codes."""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID

from app.repositories.user_verification_code_repository import (
    UserVerificationCodeRepository,
)


class VerificationPurpose:
    EMAIL_VERIFICATION = "EMAIL_VERIFICATION"
    PASSWORD_RESET = "PASSWORD_RESET"


class VerificationCodeService:
    CODE_LENGTH = 6
    CODE_EXPIRE_MINUTES = 10
    MAX_ATTEMPTS = 5

    def __init__(
        self,
        repository: UserVerificationCodeRepository,
    ) -> None:
        self.repository = repository

    @staticmethod
    def _now() -> datetime:
        return datetime.now(timezone.utc)

    @staticmethod
    def _hash_code(code: str) -> str:
        return hashlib.sha256(
            code.encode("utf-8"),
        ).hexdigest()

    @classmethod
    def _generate_code(cls) -> str:
        return "".join(
            str(secrets.randbelow(10))
            for _ in range(cls.CODE_LENGTH)
        )

    async def create_code(
        self,
        *,
        user_id: UUID,
        purpose: str,
    ) -> str:
        now = self._now()

        # Invalidate previously active codes for this user/purpose.
        await self.repository.invalidate_active_codes(
            user_id=user_id,
            purpose=purpose,
            now=now,
        )

        code = self._generate_code()

        expires_at = now + timedelta(
            minutes=self.CODE_EXPIRE_MINUTES,
        )

        await self.repository.create(
            user_id=user_id,
            purpose=purpose,
            code_hash=self._hash_code(code),
            expires_at=expires_at,
        )

        return code

    async def verify_code(
        self,
        *,
        user_id: UUID,
        purpose: str,
        code: str,
    ) -> bool:
        now = self._now()

        verification_code = (
            await self.repository.get_latest_active(
                user_id=user_id,
                purpose=purpose,
                now=now,
            )
        )

        if verification_code is None:
            return False

        if verification_code.attempts >= self.MAX_ATTEMPTS:
            return False

        expected_hash = verification_code.code_hash
        provided_hash = self._hash_code(code)

        if not secrets.compare_digest(
            expected_hash,
            provided_hash,
        ):
            await self.repository.increment_attempts(
                verification_code,
            )
            return False

        await self.repository.mark_used(
            verification_code,
            used_at=now,
        )

        return True