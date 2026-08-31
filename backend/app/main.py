import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

from app.api.routers import (
    admin_auth,
    admin_permissions,
    admin_places,
    admin_user_permissions,
    admin_users,
    auth,
    categories,
    community,
    favorites,
    health,
    places,
    reviews,
    store,
    user_point,
    wallet,
    place_contributions,
    media,
)
from app.core.config import settings


logger = logging.getLogger("wayn.backend")


app = FastAPI(
    title="WAYN Backend",
)


# ============================================================
# CORS
# ============================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=settings.cors_allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# Exception handlers
# ============================================================

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    logging.getLogger("wayn.backend.validation").warning(
        "Validation error: %s",
        exc.errors(),
    )

    return JSONResponse(
        status_code=422,
        content={
            "detail": "Validation error",
            "errors": exc.errors(),
        },
    )


@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(
    request: Request,
    exc: SQLAlchemyError,
) -> JSONResponse:
    logger.error(
        "Database error: %s",
        exc,
        exc_info=True,
    )

    return JSONResponse(
        status_code=500,
        content={
            "detail": "Database error",
        },
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    logger.error(
        "Unhandled error: %s",
        exc,
        exc_info=True,
    )

    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
        },
    )


# ============================================================
# Health
# ============================================================

app.include_router(
    health.router,
)


# ============================================================
# Authentication
# ============================================================

app.include_router(
    auth.router,
    prefix="/api/v1",
)


# ============================================================
# Categories
# ============================================================

app.include_router(
    categories.router,
    prefix="/api/v1",
)


# ============================================================
# Places
# ============================================================

app.include_router(
    places.router,
    prefix="/api/v1",
)


# ============================================================
# Reviews
# Nested under /places/{place_id}/reviews
# ============================================================

app.include_router(
    reviews.router,
    prefix="/api/v1",
)


# ============================================================
# Favorites
# ============================================================

app.include_router(
    favorites.router,
    prefix="/api/v1",
)


# ============================================================
# Community
# User-generated posts, likes, saves, and comments
# ============================================================

app.include_router(
    community.router,
    prefix="/api/v1",
)


# ============================================================
# Wallet
# ============================================================

app.include_router(
    wallet.router,
    prefix="/api/v1",
)


# ============================================================
# User Points
# ============================================================

app.include_router(
    user_point.router,
    prefix="/api/v1",
)


# ============================================================
# Store
# ============================================================

app.include_router(
    store.router,
    prefix="/api/v1",
)


# ============================================================
# Place Contributions
# ============================================================

app.include_router(
    place_contributions.router,
    prefix="/api/v1",
)


# ============================================================
# Admin Authentication
# ============================================================

app.include_router(
    admin_auth.router,
    prefix="/api/v1",
)


# ============================================================
# Admin Permissions
# ============================================================

app.include_router(
    admin_permissions.router,
    prefix="/api/v1",
)


# ============================================================
# Admin User Permissions
# ============================================================

app.include_router(
    admin_user_permissions.router,
    prefix="/api/v1",
)


# ============================================================
# Admin Places
# ============================================================

app.include_router(
    admin_places.router,
    prefix="/api/v1",
)


# ============================================================
# Admin Users
# ============================================================

app.include_router(
    admin_users.router,
    prefix="/api/v1",
)

app.include_router(
    media.router,
    prefix="/api/v1",
)