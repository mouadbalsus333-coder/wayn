"""Firebase Cloud Messaging (FCM) push service.

Responsibilities
----------------
* Lazily initialise the Firebase Admin SDK (never at import time so the
  backend boots even when credentials / dependencies are absent).
* Send push messages to a list of FCM registration tokens.
* Surface per-token success/failure from the real FCM response.
* Never leak tokens, keys or service-account contents into logs/errors.

When Firebase is not configured (no credentials or FIREBASE_ENABLED=false)
the service reports ``configured = False`` and refuses to send rather than
crashing with an opaque error.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import TYPE_CHECKING

from app.core.config import settings

if TYPE_CHECKING:
    from firebase_admin import _messaging_types  # noqa: F401


class FCMNotConfiguredError(RuntimeError):
    """Raised when Firebase is not configured."""


@dataclass
class FCMSendResult:
    """Aggregated outcome of a push send."""

    attempted: int
    success: int
    failed: int

    @property
    def all_succeeded(self) -> bool:
        return self.attempted > 0 and self.failed == 0

    @property
    def any_succeeded(self) -> bool:
        return self.success > 0


class FCMService:
    """Thin wrapper around Firebase Admin FCM."""

    def __init__(self) -> None:
        self._app = None
        self._init_error: str | None = None
        self._attempted_init = False

    @property
    def configured(self) -> bool:
        """Return whether Firebase is successfully initialized."""
        try:
            self._ensure_initialized()
        except FCMNotConfiguredError:
            return False

        return self._app is not None

    def _credentials_source(self) -> dict | str | None:
        """Return Firebase service-account credentials."""
        if settings.firebase_service_account_json:
            try:
                return json.loads(settings.firebase_service_account_json)
            except (ValueError, TypeError):
                self._init_error = (
                    "FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON"
                )
                return None

        if settings.firebase_service_account_path:
            return settings.firebase_service_account_path

        return None

    def _ensure_initialized(self) -> None:
        """Initialize Firebase Admin SDK lazily."""
        if self._attempted_init:
            if self._app is None and self._init_error:
                raise FCMNotConfiguredError(self._init_error)
            return

        self._attempted_init = True

        if not settings.firebase_enabled:
            self._init_error = (
                "Firebase is disabled (FIREBASE_ENABLED is not 'true')"
            )
            raise FCMNotConfiguredError(self._init_error)

        credentials_source = self._credentials_source()

        if credentials_source is None:
            self._init_error = (
                "Firebase credentials not configured "
                "(FIREBASE_SERVICE_ACCOUNT_JSON or "
                "FIREBASE_SERVICE_ACCOUNT_PATH required)"
            )
            raise FCMNotConfiguredError(self._init_error)

        try:
            import firebase_admin
            from firebase_admin import credentials
        except ImportError as exc:
            self._init_error = (
                f"firebase-admin SDK is not installed: {exc}"
            )
            raise FCMNotConfiguredError(self._init_error) from exc

        try:
            cred = credentials.Certificate(credentials_source)

            options = None
            if settings.firebase_project_id:
                options = {
                    "projectId": settings.firebase_project_id,
                }

            self._app = firebase_admin.initialize_app(
                cred,
                options=options,
            )

        except Exception as exc:
            self._init_error = (
                f"Firebase init failed: {type(exc).__name__}"
            )
            raise FCMNotConfiguredError(self._init_error) from exc

    def send_push(
        self,
        *,
        tokens: list[str],
        title: str,
        body: str,
        data: dict | None = None,
    ) -> FCMSendResult:
        """Send a notification to multiple FCM registration tokens."""
        if not tokens:
            return FCMSendResult(
                attempted=0,
                success=0,
                failed=0,
            )

        self._ensure_initialized()

        if self._app is None:
            raise FCMNotConfiguredError(
                self._init_error or "FCM not configured"
            )

        from firebase_admin import messaging

        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
        )

        try:
            response = messaging.send_each_for_multicast(message)
        except Exception as exc:
            raise FCMSendError(
                f"FCM send failed: {type(exc).__name__}"
            ) from exc

        success = response.success_count
        failed = response.failure_count

        for index, send_response in enumerate(response.responses):
            if send_response.success:
                print(
                    f"[FCM] token_index={index} result=success"
                )
            else:
                exception = send_response.exception

                if exception is None:
                    error_name = "UnknownError"
                else:
                    error_name = type(exception).__name__

                print(
                    f"[FCM] token_index={index} "
                    f"result=failure error={error_name}"
                )

        return FCMSendResult(
            attempted=success + failed,
            success=success,
            failed=failed,
        )


class FCMSendError(RuntimeError):
    """A push send failed at the transport level."""


fcm_service = FCMService()