import re

from app.models.place import Place
from app.models.place_social import PlaceSocial, PlaceSocialType
from app.repositories.place_social_repository import PlaceSocialRepository
from app.schemas.place_social import PlaceSocialCreate


_URL_RE = re.compile(r"^https?://\S+$", re.IGNORECASE)
# WhatsApp number: optionally a leading + followed by digits (spaces/dashes ok).
_WHATSAPP_RE = re.compile(r"^\+?[0-9][0-9\s\-()]{4,}$")


class PlaceSocialService:
    def __init__(self, repository: PlaceSocialRepository):
        self.repository = repository

    async def list_for_place(
        self,
        place_id: str,
    ) -> list[PlaceSocial]:
        return await self.repository.list_for_place(place_id)

    async def create(
        self,
        place: Place,
        data: PlaceSocialCreate,
    ) -> PlaceSocial:
        value = data.value.strip()

        if data.social_type == PlaceSocialType.WHATSAPP:
            # Only the number is stored; the app builds the wa.me link later.
            normalized = _clean_whatsapp(value)
            if not normalized or not _WHATSAPP_RE.match(normalized):
                raise ValueError("رقم واتساب غير صالح")
            value = normalized
        else:
            if not _URL_RE.match(value):
                raise ValueError("أدخل رابطًا صالحًا يبدأ بـ http(s)")

        existing = await self.repository.find_for_place_type(
            place.id,
            data.social_type,
        )
        if existing is not None:
            raise ValueError("هذه الوسيلة مضافة مسبقًا للمكان")

        social = PlaceSocial(
            place_id=place.id,
            social_type=data.social_type,
            value=value,
        )
        return await self.repository.create(social)

    async def delete(
        self,
        social: PlaceSocial,
    ) -> None:
        await self.repository.delete(social)


def _clean_whatsapp(value: str) -> str:
    """Normalize a WhatsApp phone number while keeping a leading + if present."""
    value = value.strip().replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
    return value