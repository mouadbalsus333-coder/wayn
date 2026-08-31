from email.message import EmailMessage

import aiosmtplib

from app.core.config import settings


class EmailService:
    """Service responsible for sending transactional emails."""

    def __init__(self) -> None:
        self.host = settings.brevo_smtp_host
        self.port = settings.brevo_smtp_port
        self.username = settings.brevo_smtp_username
        self.password = settings.brevo_smtp_password

        self.sender_email = settings.brevo_sender_email
        self.sender_name = settings.brevo_sender_name

    def _validate_configuration(self) -> None:
        missing = []

        if not self.host:
            missing.append("BREVO_SMTP_HOST")

        if not self.username:
            missing.append("BREVO_SMTP_USERNAME")

        if not self.password:
            missing.append("BREVO_SMTP_PASSWORD")

        if not self.sender_email:
            missing.append("BREVO_SENDER_EMAIL")

        if missing:
            raise RuntimeError(
                "Missing Brevo SMTP configuration: "
                + ", ".join(missing)
            )

    async def send_email(
        self,
        *,
        recipient: str,
        subject: str,
        body: str,
        sender: str | None = None,
    ) -> None:
        self._validate_configuration()

        message = EmailMessage()

        sender_email = sender or self.sender_email

        if self.sender_name:
            message["From"] = (
                f"{self.sender_name} <{sender_email}>"
            )
        else:
            message["From"] = sender_email

        message["To"] = recipient
        message["Subject"] = subject

        message.set_content(body)

        await aiosmtplib.send(
            message,
            hostname=self.host,
            port=self.port,
            username=self.username,
            password=self.password,
            start_tls=True,
            local_hostname="wayn.local",
        )