import os
import tempfile
from datetime import date
from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile
from sqlmodel import Session

from app.exceptions import FileTooLargeError, UnsupportedMediaTypeError
from app.models.media import Media
from app.utils.file_utils import (
    MIME_SNIFF_BYTES,
    UPLOAD_CHUNK_SIZE,
    check_disk_space,
    detect_mime_type,
    safe_extension,
)


class StorageService:
    def __init__(self, upload_dir: Path) -> None:
        self.upload_dir = upload_dir

    async def save_stream(
        self,
        file: UploadFile,
        original_filename: str,
        device_name: str,
        allowed_mime_types: set[str],
        max_bytes: int,
        disk_min_free_gb: float,
        session: Session,
    ) -> Media:
        """Schreibt den Upload in Chunks auf die Platte, ohne die Datei
        vollständig im RAM zu halten (nötig für Uploads im GB-Bereich auf
        einem Raspberry Pi mit begrenztem Arbeitsspeicher).

        MIME-Erkennung läuft auf dem ersten Chunk, bevor überhaupt ein
        Zielverzeichnis oder eine Temp-Datei angelegt wird — abgelehnte
        Uploads erzeugen keinen Disk-I/O.
        """
        first_chunk = await file.read(MIME_SNIFF_BYTES)
        detected_mime = detect_mime_type(first_chunk)
        if detected_mime not in allowed_mime_types:
            raise UnsupportedMediaTypeError(detected_mime)

        ext = safe_extension(detected_mime)
        stored_name = f"{uuid4().hex}{ext}"

        # Staging-Verzeichnis für die Temp-Datei: liegt auf demselben Dateisystem
        # wie das Zielverzeichnis (nötig für atomares os.replace()), aber
        # unabhängig von Gerät/Datum. So entsteht kein leerer Geräte/Datum-Ordner,
        # wenn ein Upload während des Streamings abgelehnt wird (zu groß, Platte
        # voll) - dieselbe "kein Orphan-Verzeichnis"-Regel wie bei Thumbnails.
        tmp_dir = self.upload_dir / ".upload-tmp"
        tmp_dir.mkdir(parents=True, exist_ok=True)

        tmp_fd, tmp_str = tempfile.mkstemp(dir=tmp_dir)
        tmp_path = Path(tmp_str)
        total_bytes = 0
        success = False
        try:
            chunk = first_chunk
            while chunk:
                total_bytes += len(chunk)
                if total_bytes > max_bytes:
                    raise FileTooLargeError(max_bytes // (1024 * 1024))
                os.write(tmp_fd, chunk)
                chunk = await file.read(UPLOAD_CHUNK_SIZE)
                if chunk:
                    # Erneute Prüfung während des Streamings (nicht nur vorab):
                    # verhindert, dass ein einzelner GB-Upload die Platte
                    # vollständig füllt, bevor das Größenlimit greift.
                    check_disk_space(self.upload_dir, disk_min_free_gb)
            success = True
        finally:
            os.close(tmp_fd)
            if not success:
                tmp_path.unlink(missing_ok=True)

        today = date.today().isoformat()
        dest_dir = self.upload_dir / device_name / today
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_path = dest_dir / stored_name
        os.replace(tmp_path, dest_path)

        # DB-Eintrag: bei Fehler wird die Datei wieder entfernt
        media = Media(
            filename=original_filename,
            stored_as=stored_name,
            mime_type=detected_mime,
            size_bytes=total_bytes,
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
