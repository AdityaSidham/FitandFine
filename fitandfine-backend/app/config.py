from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # App
    environment: str = "development"
    app_name: str = "FitandFine API"
    app_version: str = "1.0.0"
    debug: bool = False

    # Database
    database_url: str
    database_url_sync: str = ""  # For Alembic (sync driver)

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # Auth
    secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7

    # Apple Sign In
    apple_app_bundle_id: str = ""
    apple_team_id: str = ""
    apple_key_id: str = ""

    # Google OAuth
    google_client_id: str = ""

    # Gemini (Google AI Studio — free tier)
    # Get your key at: https://aistudio.google.com/app/apikey
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.0-flash"

    # USDA
    usda_api_key: str = ""

    # AWS S3
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_region: str = "us-east-1"
    s3_bucket_name: str = "fitandfine-scans"

    # Rate limits
    ai_coach_messages_per_day: int = 50
    ai_coach_messages_per_hour: int = 10
    ai_recommendations_per_day: int = 20
    label_scans_per_day: int = 30

    @property
    def sync_database_url(self) -> str:
        """Return sync DB URL for Alembic (replacing asyncpg with psycopg2)."""
        if self.database_url_sync:
            return self.database_url_sync
        return self.database_url.replace("postgresql+asyncpg://", "postgresql://")


@lru_cache
def get_settings() -> Settings:
    return Settings()
