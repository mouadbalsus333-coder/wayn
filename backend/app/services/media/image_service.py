from __future__ import annotations

from io import BytesIO

from PIL import Image, ImageOps


class ImageService:
    MAX_DIMENSION = 2048
    WEBP_QUALITY = 85

    ALLOWED_FORMATS = {
        "JPEG",
        "PNG",
        "WEBP",
        "GIF",
        "BMP",
        "TIFF",
    }

    @classmethod
    def process_image(
        cls,
        file_bytes: bytes,
    ) -> tuple[BytesIO, str]:
        if not file_bytes:
            raise ValueError("Image file is empty")

        try:
            source = Image.open(BytesIO(file_bytes))
        except Exception as exc:
            raise ValueError("Invalid image file") from exc

        if source.format not in cls.ALLOWED_FORMATS:
            raise ValueError("Unsupported image format")

        image = ImageOps.exif_transpose(source)

        if image.mode in ("RGBA", "LA"):
            converted = image.convert("RGBA")
        else:
            converted = image.convert("RGB")

        converted.thumbnail(
            (cls.MAX_DIMENSION, cls.MAX_DIMENSION),
            Image.Resampling.LANCZOS,
        )

        output = BytesIO()

        converted.save(
            output,
            format="WEBP",
            quality=cls.WEBP_QUALITY,
            method=6,
        )

        output.seek(0)

        return output, "image/webp"


image_service = ImageService()