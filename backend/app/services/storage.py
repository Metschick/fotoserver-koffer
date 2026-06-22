import os
import tempfile
from datetime import date
from pathlib import Path
from uuid import uuid4

from sqlmodel import Session

from app.models.media import Media
from app.utils.file_utils import safe_extension


class StorageService:
    def __init__(self, upload_dir: Path) -> None:
        self.upload_dir = upload_dir

    def save(
        self,
        file_data: bytes,
        original_filename: str,
        device_name: str,
        mime_type: str,
        session: Session,
    ) -> Media:
        ext = safe_extension(mime_type)
        stored_name = f"{uuid4().hex}{ext}"
        today = date.today().isoformat()

        dest_dir = self.upload_dir / device_name / today
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_path = dest_dir / stored_name

        # Atomar schreiben: erst Temp-Datei, dann os.replace() (kein partial write)
        tmp_fd, tmp_str = tempfile.mkstemp(dir=dest_dir)
        tmp_path = Path(tmp_str)
        try:
            os.write(tmp_fd, file_data)
            os.close(tmp_fd)
            os.replace(tmp_path, dest_path)
        except Exception:
            tmp_path.unlink(missing_ok=True)
            raise

        # DB-Eintrag: bei Fehler wird die Datei wieder entfernt
        media = Media(
            filename=original_filename,
            stored_as=stored_name,
            mime_type=mime_type,
            size_bytes=len(file_data),
            device_name=device_name,
        )
        try:
            session.add(media)
            session.commit()
            session.refresh(media)
        except Exception:
            dest_path.unlink(missing_ok=True)
            raise

        return media
