from uuid import UUID
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_session
from app.core.security import decode_access_token
from app.models.user import AccountStatus, User
from app.services.user.service import UserService
security = HTTPBearer(auto_error=False)
async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_session),
) -> User:
    # ============================================================
    # Authentication header
    # ============================================================
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = credentials.credentials
    # ============================================================
    # Decode and validate JWT
    # ============================================================
    try:
        payload = decode_access_token(token)
    except ValueError as exc:
        message = str(exc)
        # Preserve specific token-version errors so the client/tests
        # can distinguish a missing/invalid version from an expired
        # or otherwise invalid JWT.
        if "Token version" in message:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=message,
                headers={"WWW-Authenticate": "Bearer"},
            ) from exc
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    except TypeError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    # ============================================================
    # Token type
    # ============================================================
    if payload.get("type") != "user":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User token required",
        )
    # ============================================================
    # Token subject
    # ============================================================
    subject = payload.get("sub")
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token subject",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        user_id = UUID(subject)
    except (ValueError, TypeError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token subject",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    # ============================================================
    # Token version
    # ============================================================
    token_version = payload.get("ver")
    if token_version is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token version is missing",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        token_version = int(token_version)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token version",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    # ============================================================
    # Load user
    # ============================================================
    service = UserService(session)
    user = await service.get_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    # ============================================================
    # Token version / session invalidation
    # ============================================================
    if token_version != user.token_version:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has been invalidated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    # ============================================================
    # Account restrictions
    # ============================================================
    if user.account_status in {
        AccountStatus.SUSPENDED,
        AccountStatus.BANNED,
    }:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is restricted",
        )
    # ============================================================
    # Active account
    # ============================================================
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive",
        )
    return user
