import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from sqlalchemy.exc import SQLAlchemyError

from app.api.routers import (
    admin_auth,
    admin_places,
    auth,
    categories,
    favorites,
    health,
    places,
    reviews,
)
from app.core.config import settings

logger = logging.getLogger("wayn.backend")


app = FastAPI(
    title="WAYN Backend",
)

if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=settings.cors_allow_credentials,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    logging.getLogger("wayn.backend.validation").warning("Validation error: %s", exc.errors())
    return JSONResponse(
        status_code=422,
        content={
            "detail": "Validation error",
            "errors": exc.errors(),
        },
    )


@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(request: Request, exc: SQLAlchemyError) -> JSONResponse:
    logger.error("Database error: %s", exc, exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Database error",
        },
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.error("Unhandled error: %s", exc, exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
        },
    )


# Health
app.include_router(
    health.router,
)


# Authentication
app.include_router(
    auth.router,
    prefix="/api/v1",
)


# Categories
app.include_router(
    categories.router,
    prefix="/api/v1",
)


# Places
app.include_router(
    places.router,
    prefix="/api/v1",
)


# Reviews (nested under /places/{place_id}/reviews)
app.include_router(
    reviews.router,
    prefix="/api/v1",
)


# Favorites
app.include_router(
    favorites.router,
    prefix="/api/v1",
)


# Admin Authentication
app.include_router(
    admin_auth.router,
    prefix="/api/v1",
)


# Admin Places
app.include_router(
    admin_places.router,
    prefix="/api/v1",
)
