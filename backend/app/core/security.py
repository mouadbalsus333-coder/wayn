from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings


pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
)


def hash_password(password: str) -> str:
    """Hash a plain-text password using bcrypt."""
    return pwd_context.hash(password)


def verify_password(
    password: str,
    password_hash: str,
) -> bool:
    """Verify a plain-text password against a bcrypt hash."""
    return pwd_context.verify(
        password,
        password_hash,
    )


def create_access_token(
    subject: str,
    token_version: int = 1,
    expires_delta: timedelta | None = None,
    token_type: str = "user",
) -> str:
    """Create a JWT access token."""

    if not settings.jwt_secret_key:
        raise RuntimeError(
            "JWT_SECRET_KEY is not configured"
        )

    if expires_delta is None:
        expires_delta = timedelta(
            minutes=settings.jwt_access_token_expire_minutes
        )

    expire = datetime.now(timezone.utc) + expires_delta

    payload = {
        "sub": subject,
        "ver": token_version,
        "type": token_type,
        "exp": expire,
    }

    return jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def decode_access_token(token: str) -> dict:
    """Decode and validate a JWT access token."""

    if not settings.jwt_secret_key:
        raise RuntimeError(
            "JWT_SECRET_KEY is not configured"
        )

    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
    except JWTError as exc:
        raise ValueError(
            "Invalid or expired token"
        ) from exc

    subject = payload.get("sub")

    if not subject:
        raise ValueError(
            "Token subject is missing"
        )

    return payload
