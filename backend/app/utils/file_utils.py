import re
import shutil
from pathlib import Path

import magic

DEVICE_NAME_RE = re.compile(r"^[a-zA-Z0-9_-]{1,50}$")

# Bytes, die für die MIME-Erkennung (Magic Bytes) gelesen werden, bevor
# überhaupt etwas auf die Platte geschrieben wird. 4096 B decken die Magic-Byte-
# Signaturen aller erlaubten Formate ab (JPEG/PNG/GIF/WebP/MP4/MOV liegen alle
# in den ersten Bytes) und passen bequem in eine einzelne Netzwerk-Page.
MIME_SNIFF_BYTES = 4096

# Chunk-Größe beim Streamen großer Uploads auf die Platte. 4 MiB hält den RAM-
# Fußabdruck pro Upload konstant (unabhängig von der Dateigröße) und begrenzt
# gleichzeitig die Anzahl der Syscalls für Dateien im GB-Bereich.
UPLOAD_CHUNK_SIZE = 4 * 1024 * 1024

MIME_TO_EXT: dict[str, str] = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/gif": ".gif",
    "image/webp": ".webp",
    "video/mp4": ".mp4",
    "video/quicktime": ".mov",
}


def validate_device_name(name: str) -> str:
    if not DEVICE_NAME_RE.match(name):
        raise ValueError(
            f"Invalid device_name {name!r}. "
            r"Must match ^[a-zA-Z0-9_-]{1,50}$"
        )
    return name


def detect_mime_type(data: bytes) -> str:
    return magic.from_buffer(data, mime=True)


def safe_extension(mime_type: str) -> str:
    """Gibt die sichere Dateiendung für einen erlaubten MIME-Typ zurück.

    Gibt "" zurück wenn der MIME-Typ nicht bekannt ist. Der Router stellt
    sicher, dass nur erlaubte MIME-Typen diesen Punkt erreichen.
    """
    return MIME_TO_EXT.get(mime_type, "")


def check_file_size(size_bytes: int, max_bytes: int) -> None:
    if size_bytes > max_bytes:
        raise ValueError(
            f"File size {size_bytes} B exceeds limit of {max_bytes} B"
        )


def check_disk_space(path: Path, min_free_gb: float) -> None:
    check_path = path if path.exists() else path.parent
    usage = shutil.disk_usage(check_path)
    free_gb = usage.free / (1024**3)
    if free_gb < min_free_gb:
        raise OSError(
            f"Insufficient storage: {free_gb:.1f} GB free, "
            f"{min_free_gb} GB required"
        )
