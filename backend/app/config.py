from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="MOTIVPLAN_", env_file=".env", extra="ignore")

    # En production : postgresql+psycopg://user:password@postgres:5432/motivplan
    database_url: str = "sqlite:///./motivplan.db"
    # Jeton statique partagé avec l'app (Keychain côté iOS). Vide = toute requête authentifiée refusée.
    api_token: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings()
