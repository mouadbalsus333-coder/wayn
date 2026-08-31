"""Media serving routes."""

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import Response

from app.services.media.media_service import media_service

router = APIRouter(
    prefix="/media",
    tags=["Media"],
)


@router.get("/{object_key:path}")
async def get_media_file(object_key: str) -> Response:
    try:
        file_bytes, content_type = media_service.get_file(object_key)
        return Response(
            content=file_bytes,
            media_type=content_type,
            headers={
                "Cache-Control": "public, max-age=31536000, immutable",
            },
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Media file not found",
        ) from exc
