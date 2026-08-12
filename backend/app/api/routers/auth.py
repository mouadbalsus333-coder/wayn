from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.auth import get_current_user
from app.core.database import get_session
from app.core.security import create_access_token
from app.models.user import User
from app.schemas.user_auth import (
    AuthResponse,
    LocationRequest,
    PasswordChangeRequest,
    UserLoginRequest,
    UserProfileUpdateRequest,
    UserRead,
    UserRegisterRequest,
)
from app.services.user.service import UserService

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    data: UserRegisterRequest,
    session: AsyncSession = Depends(get_session),
):
    service = UserService(session)

    try:
        user = await service.register(
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
            headers={"WWW-Authenticate": "Bearer"},
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


@router.get(
    "/me",
    response_model=UserRead,
)
async def get_me(
    current_user: User = Depends(get_current_user),
):
    return current_user


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