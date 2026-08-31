from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.core.security import create_access_token
from app.models.user import User
from app.repositories.user_verification_code_repository import (
    UserVerificationCodeRepository,
)
from app.schemas.user_auth import (
    AuthResponse,
    EmailVerificationRequest,
    ForgotPasswordRequest,
    GoogleLoginRequest,
    LocationRequest,
    PasswordChangeRequest,
    PasswordResetRequest,
    RegistrationResponse,
    ResendVerificationRequest,
    UserLoginRequest,
    UserProfileUpdateRequest,
    UserRead,
    UserRegisterRequest,
    VerificationResponse,
)
from app.services.email.service import EmailService
from app.services.user.service import UserService
from app.services.verification_code_service import (
    VerificationCodeService,
    VerificationPurpose,
)


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


# ============================================================
# Registration
# ============================================================


@router.post(
    "/register",
    response_model=RegistrationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    data: UserRegisterRequest,
    session: AsyncSession = Depends(get_session),
):
    user_service = UserService(session)

    try:
        user = await user_service.register(
            email=data.email,
            password=data.password,
            full_name=data.full_name,
            username=data.username,
            phone=data.phone,
            avatar_id=data.avatar_id,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    # --------------------------------------------------------
    # Create verification code
    # --------------------------------------------------------

    verification_repository = (
        UserVerificationCodeRepository(session)
    )

    verification_service = VerificationCodeService(
        verification_repository
    )

    code = await verification_service.create_code(
        user_id=user.id,
        purpose=(
            VerificationPurpose.EMAIL_VERIFICATION
        ),
    )

    # --------------------------------------------------------
    # Send verification email
    # --------------------------------------------------------

    email_service = EmailService()

    try:
        await email_service.send_email(
            recipient=user.email,
            subject="WAYN - Verify your email",
            body=(
                f"Hello {user.full_name},\n\n"
                "Your WAYN verification code is:\n\n"
                f"{code}\n\n"
                "This code expires in 10 minutes.\n\n"
                "If you did not create a WAYN account, "
                "you can ignore this email."
            ),
        )

    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Account created, but verification email "
                "could not be sent. Please use the resend "
                "verification option."
            ),
        ) from exc

    return RegistrationResponse(
        user=UserRead.model_validate(user),
        verification_required=True,
        message=(
            "Registration successful. "
            "A verification code has been sent to your email."
        ),
    )


# ============================================================
# Login
# ============================================================


@router.post(
    "/login",
    response_model=AuthResponse,
)
async def login(
    data: UserLoginRequest,
    session: AsyncSession = Depends(get_session),
):
    service = UserService(session)

    user = await service.authenticate(
        email=data.email,
        password=data.password,
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={
                "WWW-Authenticate": "Bearer"
            },
        )

    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email address is not verified",
        )

    access_token = create_access_token(
        subject=str(user.id),
        token_version=user.token_version,
        token_type="user",
    )

    return AuthResponse(
        access_token=access_token,
        token_type="bearer",
        user=UserRead.model_validate(user),
    )


# ============================================================
# Email verification
# ============================================================


@router.post(
    "/verify-email",
    response_model=VerificationResponse,
)
async def verify_email(
    data: EmailVerificationRequest,
    session: AsyncSession = Depends(get_session),
):
    user_service = UserService(session)

    user = await user_service.get_by_email(
        data.email
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification request",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is not active",
        )

    if user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email address is already verified",
        )

    verification_repository = (
        UserVerificationCodeRepository(session)
    )

    verification_service = VerificationCodeService(
        verification_repository
    )

    is_valid = await verification_service.verify_code(
        user_id=user.id,
        purpose=(
            VerificationPurpose.EMAIL_VERIFICATION
        ),
        code=data.code,
    )

    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code",
        )

    user = await user_service.verify_email(user)

    access_token = create_access_token(
        subject=str(user.id),
        token_version=user.token_version,
        token_type="user",
    )

    return VerificationResponse(
        access_token=access_token,
        token_type="bearer",
        user=UserRead.model_validate(user),
    )


# ============================================================
# Resend email verification
# ============================================================


@router.post(
    "/resend-verification",
)
async def resend_verification(
    data: ResendVerificationRequest,
    session: AsyncSession = Depends(get_session),
):
    user_service = UserService(session)

    user = await user_service.get_by_email(
        data.email
    )

    # Do not reveal whether an email exists.
    if user is None:
        return {
            "message": (
                "If the account exists, "
                "a verification email has been sent."
            )
        }

    if user.is_verified:
        return {
            "message": "Email address is already verified."
        }

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is not active",
        )

    verification_repository = (
        UserVerificationCodeRepository(session)
    )

    verification_service = VerificationCodeService(
        verification_repository
    )

    code = await verification_service.create_code(
        user_id=user.id,
        purpose=(
            VerificationPurpose.EMAIL_VERIFICATION
        ),
    )

    email_service = EmailService()

    try:
        await email_service.send_email(
            recipient=user.email,
            subject="WAYN - New verification code",
            body=(
                f"Hello {user.full_name},\n\n"
                "Your new WAYN verification code is:\n\n"
                f"{code}\n\n"
                "This code expires in 10 minutes."
            ),
        )

    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Verification email could not be sent",
        ) from exc

    return {
        "message": "A new verification code has been sent."
    }


# ============================================================
# Forgot password
# ============================================================


@router.post(
    "/forgot-password",
)
async def forgot_password(
    data: ForgotPasswordRequest,
    session: AsyncSession = Depends(get_session),
):
    user_service = UserService(session)

    user = await user_service.get_by_email(
        data.email
    )

    # Always return the same response.
    # This prevents email enumeration.
    if user is None:
        return {
            "message": (
                "If the account exists, "
                "a password reset code has been sent."
            )
        }

    if not user.is_active:
        return {
            "message": (
                "If the account exists, "
                "a password reset code has been sent."
            )
        }

    verification_repository = (
        UserVerificationCodeRepository(session)
    )

    verification_service = VerificationCodeService(
        verification_repository
    )

    code = await verification_service.create_code(
        user_id=user.id,
        purpose=VerificationPurpose.PASSWORD_RESET,
    )

    email_service = EmailService()

    try:
        await email_service.send_email(
            recipient=user.email,
            subject="WAYN - Password reset code",
            body=(
                f"Hello {user.full_name},\n\n"
                "Your WAYN password reset code is:\n\n"
                f"{code}\n\n"
                "This code expires in 10 minutes.\n\n"
                "If you did not request a password reset, "
                "you can ignore this email."
            ),
        )

    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Password reset email could not be sent",
        ) from exc

    return {
        "message": (
            "If the account exists, "
            "a password reset code has been sent."
        )
    }


# ============================================================
# Reset password
# ============================================================


@router.post(
    "/reset-password",
)
async def reset_password(
    data: PasswordResetRequest,
    session: AsyncSession = Depends(get_session),
):
    user_service = UserService(session)

    user = await user_service.get_by_email(
        data.email
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid password reset request",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is not active",
        )

    verification_repository = (
        UserVerificationCodeRepository(session)
    )

    verification_service = VerificationCodeService(
        verification_repository
    )

    is_valid = await verification_service.verify_code(
        user_id=user.id,
        purpose=VerificationPurpose.PASSWORD_RESET,
        code=data.code,
    )

    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired password reset code",
        )

    await user_service.reset_password(
        user=user,
        new_password=data.new_password,
    )

    return {
        "message": "Password has been reset successfully."
    }


# ============================================================
# Current user
# ============================================================


@router.get(
    "/me",
    response_model=UserRead,
)
async def get_me(
    current_user: User = Depends(get_current_user),
):
    return current_user


# ============================================================
# Update profile
# ============================================================


@router.put(
    "/me",
    response_model=UserRead,
)
async def update_my_profile(
    data: UserProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    service = UserService(session)

    try:
        user = await service.update_profile(
            user=current_user,
            full_name=data.full_name,
            username=data.username,
            phone=data.phone,
            avatar_id=data.avatar_id,
            bio=data.bio,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    return UserRead.model_validate(user)


# ============================================================
# Change password
# ============================================================


@router.put(
    "/me/password",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def change_my_password(
    data: PasswordChangeRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    service = UserService(session)

    try:
        await service.change_password(
            user=current_user,
            current_password=data.current_password,
            new_password=data.new_password,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


# ============================================================
# Update location
# ============================================================


@router.put(
    "/me/location",
    response_model=UserRead,
)
async def update_my_location(
    data: LocationRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    service = UserService(session)

    user = await service.update_location(
        user=current_user,
        latitude=data.latitude,
        longitude=data.longitude,
        source=data.source,
    )

    return UserRead.model_validate(user)
