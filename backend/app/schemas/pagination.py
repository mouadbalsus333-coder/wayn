"""Unified pagination schema for WAYN backend.

NOTE: The current public API returns a plain list in the response body
and exposes pagination metadata via response headers
(X-Total-Count, X-Page, X-Limit, X-Pages) to preserve backward
compatibility with the existing Flutter client.

This schema is provided as the canonical shape for future paginated
responses and for OpenAPI documentation.
"""
from __future__ import annotations

from typing import Generic, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class PaginatedResponse(BaseModel, Generic[T]):
    """Unified pagination response wrapper.

    Attributes:
        items: The list of items for the current page.
        total: Total number of items matching the query (not just page length).
        page: Current page number (1-based).
        limit: Number of items per page.
        pages: Total number of pages (ceil(total / limit)).
    """

    items: list[T]
    total: int = Field(ge=0)
    page: int = Field(ge=1)
    limit: int = Field(ge=1)
    pages: int = Field(ge=0)