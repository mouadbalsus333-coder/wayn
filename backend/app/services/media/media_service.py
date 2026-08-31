from __future__ import annotations

from app.services.media.image_service import image_service
from app.services.media.r2_service import r2_service


class MediaService:
    def upload_image(
        self,
        file_bytes: bytes,
        object_key: str,
    ) -> str:
        processed_image, content_type = image_service.process_image(
            file_bytes,
        )

        r2_service.upload_file(
            processed_image,
            object_key,
            content_type,
        )

        return object_key

    def get_file(
        self,
        object_key: str,
    ) -> tuple[bytes, str]:
        return r2_service.get_file(object_key)

    def delete_file(
        self,
        object_key: str,
    ) -> None:
        r2_service.delete_file(object_key)


media_service = MediaService()
