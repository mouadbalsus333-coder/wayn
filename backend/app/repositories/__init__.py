"""Repository package for the WAYN backend."""

from .admin_notification_repository import AdminNotificationRepository
from .device_repository import DeviceRepository

__all__ = [
    "AdminNotificationRepository",
    "DeviceRepository",
]
