import logging
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageOps

logger = logging.getLogger(__name__)

THUMB_SIZE = (300, 300)


class ThumbnailService:
    def __init__(self, upload_dir: Path) -> None:
        self.upload_dir = upload_dir

    def generate(self, source_path: Path, mime_type: str) -> str | None:
        """Erzeugt ein Thumbnail für eine gespeicherte Mediendatei.

        Gibt den Pfad relativ zu upload_dir zurück, oder None bei Fehler.
        Der Upload schlägt bei Thumbnail-Fehlern nicht fehl.
        """
        thumb_dir = source_path.parent / "thumbnails"
        thumb_path = thumb_dir / f"{source_path.stem}_thumb.jpg"

        try:
            if mime_type.startswith("image/"):
                self._from_image(source_path, thumb_path)
            elif mime_type.startswith("video/"):
                self._from_video(source_path, thumb_path)
            else:
                return None
        except Exception:
            logger.exception("Thumbnail generation failed for %s", source_path.name)
            thumb_path.unlink(missing_ok=True)
            return None

        return str(thumb_path.relative_to(self.upload_dir))

    def _from_image(self, source: Path, dest: Path) -> None:
        # FIX: exif_transpose() gibt ein neues Image-Objekt zurück wenn
        # eine Rotation nötig ist. Das Original wird durch den with-Block
        # geschlossen; das neue Objekt muss separat geschlossen werden.
        with Image.open(source) as raw:
            img = ImageOps.exif_transpose(raw)
            try:
                if img.mode not in ("RGB", "L"):
                    img = img.convert("RGB")
                img.thumbnail(THUMB_SIZE, Image.Resampling.LANCZOS)
                # Verzeichnis erst anlegen wenn Pillow die Datei öffnen konnte
                dest.parent.mkdir(parents=True, exist_ok=True)
                img.save(dest, format="JPEG", quality=80, optimize=True)
            finally:
                if img is not raw:
                    img.close()

    def _from_video(self, source: Path, dest: Path) -> None:
        if shutil.which("ffmpeg") is None:
            raise FileNotFoundError("ffmpeg not found in PATH")

        dest.parent.mkdir(parents=True, exist_ok=True)
        try:
            result = subprocess.run(
                [
                    "ffmpeg", "-y",
                    "-i", str(source),
                    "-vframes", "1",
                    "-vf", (
                        f"scale={THUMB_SIZE[0]}:{THUMB_SIZE[1]}"
                        ":force_original_aspect_ratio=decrease"
                    ),
                    "-q:v", "5",
                    str(dest),
                ],
                capture_output=True,
                timeout=30,
            )
        except subprocess.TimeoutExpired as exc:
            # Zombie-Prozess verhindern: ffmpeg explizit beenden
            if exc.process is not None:
                exc.process.kill()
            dest.unlink(missing_ok=True)
            _rmdir_if_empty(dest.parent)
            raise RuntimeError("ffmpeg timed out") from exc

        if result.returncode != 0:
            dest.unlink(missing_ok=True)
            _rmdir_if_empty(dest.parent)
            raise RuntimeError(
                f"ffmpeg exited {result.returncode}: "
                f"{result.stderr.decode(errors='replace')[:200]}"
            )


def _rmdir_if_empty(path: Path) -> None:
    try:
        path.rmdir()
    except OSError:
        pass
