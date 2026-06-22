import re
from datetime import datetime, timezone
from typing import Optional

from pydantic import field_validator
from sqlmodel import Field, SQLModel

_DEVICE_NAME_RE = re.compile(r"^[a-zA-Z0-9_-]{1,50}$")


class Media(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)

    # Originalname – nur Metadatum, niemals als Dateipfad verwenden
    filename: str = Field(index=False)

    # UUID-basierter Dateiname auf der Festplatte
    stored_as: str = Field(unique=True)

    mime_type: str
    size_bytes: int

    # Gerätename aus Upload-Formular, Whitelist-validiert vor Speicherung
    device_name: str = Field(index=True)

    uploaded_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        index=True,
    )

    # Relativer Pfad zum Thumbnail, null wenn noch nicht generiert
    thumb_path: Optional[str] = Field(default=None)

    @field_validator("device_name")
    @classmethod
    def device_name_must_be_safe(cls, v: str) -> str:
        if not _DEVICE_NAME_RE.match(v):
            raise ValueError(
                "device_name must match ^[a-zA-Z0-9_-]{1,50}$ "
                "(only letters, digits, hyphens, underscores, max 50 chars)"
            )
        return v

    @property
    def album_path(self) -> str:
        """Pfad relativ zu upload_dir: Gerätename/YYYY-MM-DD"""
        return f"{self.device_name}/{self.uploaded_at.strftime('%Y-%m-%d')}"
