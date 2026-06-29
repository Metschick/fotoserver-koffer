from functools import lru_cache
from pathlib import Path
from typing import ClassVar

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Verzeichnisse
    upload_dir: Path = Path("./uploads")
    data_dir: Path = Path("./data")

    # Upload-Limits
    max_file_size_mb: int = 100
    disk_min_free_gb: int = 2
    allowed_types: str = (
        "image/jpeg,image/png,image/gif,image/webp,"
        "video/mp4,video/quicktime"
    )

    # Sicherheit
    secret_key: str = "CHANGE_ME"
    user_password_hash: str = ""
    admin_password_hash: str = ""

    @field_validator("secret_key")
    @classmethod
    def secret_key_must_be_set(cls, v: str) -> str:
        if v == "CHANGE_ME" or len(v) < 32:
            raise ValueError("secret_key must be set to a random value of >=32 characters")
        return v

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    log_level: str = "INFO"

    _valid_log_levels: ClassVar[frozenset[str]] = frozenset(
        {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}
    )

    @field_validator("log_level")
    @classmethod
    def log_level_must_be_valid(cls, v: str) -> str:
        upper = v.upper()
        if upper not in cls._valid_log_levels:
            raise ValueError(
                f"log_level muss eines von {sorted(cls._valid_log_levels)} sein, "
                f"erhalten: {v!r}"
            )
        return upper

    @property
    def allowed_mime_types(self) -> set[str]:
        return {t.strip() for t in self.allowed_types.split(",") if t.strip()}

    @property
    def db_path(self) -> Path:
        return self.data_dir / "fotoserver.db"

    @property
    def max_file_size_bytes(self) -> int:
        return self.max_file_size_mb * 1024 * 1024


@lru_cache
def get_settings() -> Settings:
    return Settings()
