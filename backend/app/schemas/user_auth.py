from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


# ============================================================
# Registration
# ============================================================


class UserRegisterRequest(BaseModel):
    email: EmailStr

    password: str = Field(
        min_length=8,
        max_length=128,
    )

    full_name: str = Field(
        min_length=2,
        max_length=255,
    )

    username: str = Field(
        min_length=3,
        max_length=50,
    )

    phone: str | None = Field(
        default=None,
        max_length=32,
    )

    avatar_id: str | None = Field(
        default=None,
        max_length=100,
    )


# ============================================================
# Login
# ============================================================


class UserLoginRequest(BaseModel):
    email: EmailStr
    password: str


class GoogleLoginRequest(BaseModel):
    id_token: str = Field(
        min_length=1,
    )


# ============================================================
# Location
# ============================================================


class LocationRequest(BaseModel):
    latitude: float = Field(
        ge=-90,
        le=90,
    )

    longitude: float = Field(
        ge=-180,
        le=180,
    )

    source: str = Field(
        pattern=r"^(automatic|manual)$",
    )


# ============================================================
# Profile
# ============================================================


class UserProfileUpdateRequest(BaseModel):
    full_name: str | None = Field(
        default=None,
        min_length=2,
        max_length=255,
    )

    username: str | None = Field(
        default=None,
        min_length=3,
        max_length=50,
    )

    phone: str | None = Field(
        default=None,
        max_length=32,
    )

    avatar_id: str | None = Field(
        default=None,
        max_length=100,
    )

    bio: str | None = Field(
        default=None,
        max_length=2000,
    )


# ============================================================
# Password change
# ============================================================


class PasswordChangeRequest(BaseModel):
    current_password: str = Field(
        min_length=1,
        max_length=128,
    )

    new_password: str = Field(
        min_length=8,
        max_length=128,
    )


# ============================================================
# Email verification
# ============================================================


class EmailVerificationRequest(BaseModel):
    email: EmailStr

    code: str = Field(
        min_length=6,
        max_length=6,
        pattern=r"^\d{6}$",
    )


class ResendVerificationRequest(BaseModel):
    email: EmailStr


# ============================================================
# Password reset
# ============================================================


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class PasswordResetRequest(BaseModel):
    email: EmailStr

    code: str = Field(
        min_length=6,
        max_length=6,
        pattern=r"^\d{6}$",
    )

    new_password: str = Field(
        min_length=8,
        max_length=128,
    )


# ============================================================
# Authentication responses
# ============================================================


class UserRead(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str
    username: str
    phone: str | None
    avatar_id: str | None
    bio: str | None
    latitude: float | None
    longitude: float | None
    location_source: str | None
    is_active: bool
    is_verified: bool

    model_config = {
        "from_attributes": True,
    }


class AuthResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserRead


class RegistrationResponse(BaseModel):
    user: UserRead

    verification_required: bool = True

    message: str


class VerificationResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserRead
