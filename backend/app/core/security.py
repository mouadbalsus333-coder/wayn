from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings


# ============================================================
# Password hashing
# ============================================================

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
)


def hash_password(password: str) -> str:
    """Hash a plain-text password using bcrypt."""
    if not password:
        raise ValueError("Password cannot be empty")

    return pwd_context.hash(password)


def verify_password(
    password: str,
    password_hash: str,
) -> bool:
    """Verify a plain-text password against a bcrypt hash."""
    if not password or not password_hash:
        return False

    try:
        return pwd_context.verify(
            password,
            password_hash,
        )
    except (ValueError, TypeError):
        return False


# ============================================================
# JWT validation
# ============================================================

def _validate_jwt_configuration() -> None:
    """Validate the JWT configuration before signing or decoding."""
    secret = settings.jwt_secret_key

    if not secret:
        raise RuntimeError(
            "JWT_SECRET_KEY is not configured"
        )

    if len(secret) < 32:
        raise RuntimeError(
            "JWT_SECRET_KEY must contain at least 32 characters"
        )

    if settings.jwt_algorithm != "HS256":
        raise RuntimeError(
            "Unsupported JWT algorithm. WAYN currently requires HS256."
        )


# ============================================================
# Access token
# ============================================================

def create_access_token(
    subject: str,
    token_version: int = 1,
    expires_delta: timedelta | None = None,
    token_type: str = "user",
) -> str:
    """Create a signed JWT access token."""

    _validate_jwt_configuration()

    if not subject:
        raise ValueError(
            "Token subject cannot be empty"
        )

    if token_version < 0:
        raise ValueError(
            "Token version cannot be negative"
        )

    if not token_type:
        raise ValueError(
            "Token type cannot be empty"
        )

    if expires_delta is None:
        expires_delta = timedelta(
            minutes=settings.jwt_access_token_expire_minutes
        )

    if expires_delta.total_seconds() <= 0:
        raise ValueError(
            "Token expiration must be greater than zero"
        )

    now = datetime.now(timezone.utc)
    expire = now + expires_delta

    payload = {
        "sub": str(subject),
        "ver": int(token_version),
        "type": token_type,
        "iat": now,
        "exp": expire,
    }

    return jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm="HS256",
    )


def decode_access_token(token: str) -> dict:
    """Decode and validate a signed JWT access token."""

    _validate_jwt_configuration()

    if not token:
        raise ValueError(
            "Token cannot be empty"
        )

    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=["HS256"],
            options={
                "require_exp": True,
                "require_sub": True,
            },
        )
    except JWTError as exc:
        raise ValueError(
            "Invalid or expired token"
        ) from exc

    subject = payload.get("sub")

    if not subject or not isinstance(subject, str):
        raise ValueError(
            "Token subject is missing or invalid"
        )

    token_type = payload.get("type")

    if not token_type or not isinstance(token_type, str):
        raise ValueError(
            "Token type is missing or invalid"
        )

    token_version = payload.get("ver")

    if token_version is None:
        raise ValueError(
            "Token version is missing"
        )

    try:
        token_version = int(token_version)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            "Token version is invalid"
        ) from exc

    if token_version < 0:
        raise ValueError(
            "Token version is invalid"
        )

    return payload