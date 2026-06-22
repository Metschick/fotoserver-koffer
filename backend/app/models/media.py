from datetime import datetime, timezone
from typing import Optional

from pydantic import BaseModel, field_validator
from sqlalchemy import Index
from sqlmodel import Field, SQLModel

from app.utils.file_utils import validate_device_name


class Media(SQLModel, table=True):
    __table_args__ = (
        # Kompositindex für Album-Abfragen: WHERE device_name=? ORDER BY uploaded_at
        Index("ix_media_device_uploaded", "device_name", "uploaded_at"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)

    # Originalname – nur Metadatum, niemals als Dateipfad verwenden
    filename: str = Field(index=False)

    # UUID-basierter Dateiname auf der Festplatte
    stored_as: str = Field(unique=True)

    mime_type: str
    size_bytes: int

    # Gerätename aus Upload-Formular, Whitelist-validiert
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
        return validate_device_name(v)

    @property
    def album_path(self) -> str:
        """Pfad relativ zu upload_dir: Gerätename/YYYY-MM-DD"""
        return f"{self.device_name}/{self.uploaded_at.strftime('%Y-%m-%d')}"


class MediaRead(BaseModel):
    """API-Antwortschema für ein einzelnes Medium."""

    id: int
    filename: str
    mime_type: str
    size_bytes: int
    device_name: str
    uploaded_at: datetime
    album_path: str
    thumb_path: Optional[str]

    @classmethod
    def from_media(cls, m: Media) -> "MediaRead":
        return cls(
            id=m.id,
            filename=m.filename,
            mime_type=m.mime_type,
            size_bytes=m.size_bytes,
            device_name=m.device_name,
            uploaded_at=m.uploaded_at,
            album_path=m.album_path,
            thumb_path=m.thumb_path,
        )


class GalleryPage(BaseModel):
    """Paginiertes Ergebnis einer Galerie-Abfrage."""

    items: list[MediaRead]
    total: int
    limit: int
    offset: int
