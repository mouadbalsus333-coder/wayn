import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    def __init__(self) -> None:
        # In test mode, prefer TEST_DATABASE_URL if provided.
        if os.environ.get("ENV") == "test":
            self.database_url = os.environ.get(
                "TEST_DATABASE_URL",
                os.environ.get(
                    "DATABASE_URL",
                    "postgresql+asyncpg://wayn_user:wayn_password@localhost:5432/wayn_test_db",
                ),
            )
        else:
            self.database_url = os.environ.get(
                "DATABASE_URL",
                "postgresql+asyncpg://wayn_user:wayn_password@localhost:5432/wayn_db",
            )

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

        cors_origins_env = os.environ.get("CORS_ORIGINS", "")
        if cors_origins_env:
            self.cors_origins = [origin.strip() for origin in cors_origins_env.split(",") if origin.strip()]
        else:
            self.cors_origins = []

        self.cors_allow_credentials = os.environ.get("CORS_ALLOW_CREDENTIALS", "true").lower() == "true"


settings = Settings()
