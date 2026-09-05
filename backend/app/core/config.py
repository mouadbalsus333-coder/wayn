import os

from dotenv import load_dotenv


# ============================================================
# Environment
# ============================================================

ENVIRONMENT = os.environ.get(
    "ENV",
    "",
).strip().lower()

if ENVIRONMENT == "test":
    load_dotenv(
        ".env.test",
        override=True,
    )
else:
    load_dotenv(
        ".env",
        override=True,
    )


class Settings:
    def __init__(self) -> None:
        # ----------------------------------------------------
        # Environment
        # ----------------------------------------------------

        self.env = os.environ.get(
            "ENV",
            "development",
        ).strip().lower()

        # ----------------------------------------------------
        # Database
        # ----------------------------------------------------

        if self.env == "test":
            self.database_url = os.environ.get(
                "TEST_DATABASE_URL",
                os.environ.get(
                    "DATABASE_URL",
                    (
                        "postgresql+asyncpg://"
                        "wayn_user:wayn_password"
                        "@localhost:5432/wayn_test_db"
                    ),
                ),
            )
        else:
            self.database_url = os.environ.get(
                "DATABASE_URL",
                (
                    "postgresql+asyncpg://"
                    "wayn_user:wayn_password"
                    "@localhost:5432/wayn_db"
                ),
            )

        # ----------------------------------------------------
        # JWT
        # ----------------------------------------------------

        self.jwt_secret_key = os.environ.get(
            "JWT_SECRET_KEY",
            "",
        )

        self.jwt_algorithm = os.environ.get(
            "JWT_ALGORITHM",
            "HS256",
        )

        self.jwt_access_token_expire_minutes = int(
            os.environ.get(
                "JWT_ACCESS_TOKEN_EXPIRE_MINUTES",
                "60",
            )
        )

        # ----------------------------------------------------
        # CORS
        # ----------------------------------------------------

        cors_origins_env = os.environ.get(
            "CORS_ORIGINS",
            "",
        )

        if cors_origins_env:
            self.cors_origins = [
                origin.strip()
                for origin in cors_origins_env.split(",")
                if origin.strip()
            ]
        else:
            self.cors_origins = (
                ["http://localhost:5173"]
                if self.env in {"development", "dev", "test"}
                else ["https://admin.wayn.ly"]
            )

        self.cors_allow_credentials = (
            os.environ.get(
                "CORS_ALLOW_CREDENTIALS",
                "true",
            ).strip().lower()
            == "true"
        )

        if (
            "*" in self.cors_origins
            and self.cors_allow_credentials
        ):
            raise ValueError(
                "Wildcard CORS origins are incompatible with credentials"
            )

        self.admin_cookie_name = os.environ.get(
            "ADMIN_AUTH_COOKIE_NAME",
            "wayn_admin_session",
        )

        self.admin_cookie_secure = (
            os.environ.get(
                "ADMIN_AUTH_COOKIE_SECURE",
                "true" if self.env == "production" else "false",
            ).strip().lower()
            == "true"
        )

        self.admin_cookie_samesite = os.environ.get(
            "ADMIN_AUTH_COOKIE_SAMESITE",
            "strict",
        ).strip().lower()

        if self.admin_cookie_samesite not in {
            "strict",
            "lax",
            "none",
        }:
            raise ValueError(
                "ADMIN_AUTH_COOKIE_SAMESITE must be strict, lax, or none"
            )

        # ----------------------------------------------------
        # OSRM Routing
        # ----------------------------------------------------
        #
        # WAYN uses OSRM for road-route calculation.
        #
        # Keep the OSRM server configurable so the application
        # can use the public OSRM service during development
        # and later switch to a self-hosted OSRM instance
        # without changing application code.
        #
        # Example:
        #
        # OSRM_BASE_URL=https://router.project-osrm.org
        #
        # ----------------------------------------------------

        self.osrm_base_url = os.environ.get(
            "OSRM_BASE_URL",
            "https://router.project-osrm.org",
        ).rstrip("/")

        self.osrm_timeout_seconds = float(
            os.environ.get(
                "OSRM_TIMEOUT_SECONDS",
                "10",
            )
        )

        # ----------------------------------------------------
        # Brevo SMTP
        # ----------------------------------------------------

        self.brevo_smtp_host = os.environ.get(
            "BREVO_SMTP_HOST",
            "smtp-relay.brevo.com",
        )

        self.brevo_smtp_port = int(
            os.environ.get(
                "BREVO_SMTP_PORT",
                "587",
            )
        )

        self.brevo_smtp_username = os.environ.get(
            "BREVO_SMTP_USERNAME",
            "",
        )

        self.brevo_smtp_password = os.environ.get(
            "BREVO_SMTP_PASSWORD",
            "",
        )

        # ----------------------------------------------------
        # Brevo Sender
        # ----------------------------------------------------

        self.brevo_sender_email = os.environ.get(
            "BREVO_SENDER_EMAIL",
            "",
        )

        self.brevo_sender_name = os.environ.get(
            "BREVO_SENDER_NAME",
            "WAYN",
        )

        # ----------------------------------------------------
        # Cloudflare R2
        # ----------------------------------------------------

        self.r2_account_id = os.environ.get(
            "R2_ACCOUNT_ID",
            "",
        )

        self.r2_access_key_id = os.environ.get(
            "R2_ACCESS_KEY_ID",
            "",
        )

        self.r2_secret_access_key = os.environ.get(
            "R2_SECRET_ACCESS_KEY",
            "",
        )

        self.r2_bucket_name = os.environ.get(
            "R2_BUCKET_NAME",
            "wayn-media",
        )

        self.r2_region = os.environ.get(
            "R2_REGION",
            "auto",
        )

        # ----------------------------------------------------
        # Cloudflare R2 Endpoint
        # ----------------------------------------------------

        self.r2_endpoint_url = os.environ.get(
            "R2_ENDPOINT_URL",
            "",
        )

        if (
            not self.r2_endpoint_url
            and self.r2_account_id
        ):
            self.r2_endpoint_url = (
                f"https://{self.r2_account_id}"
                ".r2.cloudflarestorage.com"
            )

        # ----------------------------------------------------
        # Cloudflare R2 Public URL
        # ----------------------------------------------------
        #
        # Keep this empty until we configure either:
        # - a Custom Domain, or
        # - another controlled public delivery URL.
        #
        # Do NOT use the S3 endpoint as a public media URL.
        #
        # ----------------------------------------------------

        self.r2_public_url = os.environ.get(
            "R2_PUBLIC_URL",
            "",
        )


# ============================================================
# Global settings instance
# ============================================================

settings = Settings()