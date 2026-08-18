import os

from dotenv import load_dotenv


# ============================================================
# Environment
# ============================================================
#
# The application can run in different environments:
#
#   ENV=test
#       -> .env.test
#
#   ENV=development / production / empty
#       -> .env
#
# Tests and Alembic can explicitly set ENV=test before importing
# this module.
# ============================================================

ENVIRONMENT = os.environ.get("ENV", "").strip().lower()

if ENVIRONMENT == "test":
    load_dotenv(".env.test", override=True)
else:
    load_dotenv(".env", override=True)


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
        #
        # Test environment:
        #   Prefer TEST_DATABASE_URL.
        #
        # Other environments:
        #   Use DATABASE_URL.
        #
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
            self.cors_origins = []

        self.cors_allow_credentials = (
            os.environ.get(
                "CORS_ALLOW_CREDENTIALS",
                "true",
            ).strip().lower()
            == "true"
        )


# ============================================================
# Global settings instance
# ============================================================

settings = Settings()