import io
import subprocess
from pathlib import Path

from PIL import Image

from app.services.thumbnail import ThumbnailService


def _make_jpeg(width: int, height: int, color: tuple[int, int, int] = (100, 150, 200)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (width, height), color=color).save(buf, format="JPEG")
    return buf.getvalue()


def _make_png(width: int, height: int) -> bytes:
    buf = io.BytesIO()
    Image.new("RGBA", (width, height), color=(255, 0, 0, 128)).save(buf, format="PNG")
    return buf.getvalue()


def _source_in(upload_dir: Path, filename: str = "abc123.jpg") -> Path:
    dest_dir = upload_dir / "device" / "2026-06-22"
    dest_dir.mkdir(parents=True, exist_ok=True)
    return dest_dir / filename


# ---------------------------------------------------------------------------
# Erfolgreiche Thumbnail-Erzeugung
# ---------------------------------------------------------------------------

def test_thumb_from_valid_jpeg(tmp_path):
    upload_dir = tmp_path / "uploads"
    source = _source_in(upload_dir)
    source.write_bytes(_make_jpeg(200, 200))

    result = ThumbnailService(upload_dir).generate(source, "image/jpeg")

    assert result is not None
    thumb = upload_dir / result
    assert thumb.exists()
    with Image.open(thumb) as img:
        assert img.size[0] <= 300
        assert img.size[1] <= 300


def test_thumb_from_valid_png(tmp_path):
    upload_dir = tmp_path / "uploads"
    source = _source_in(upload_dir, "abc123.png")
    source.write_bytes(_make_png(150, 150))

    result = ThumbnailService(upload_dir).generate(source, "image/png")

    assert result is not None
    assert (upload_dir / result).exists()


def test_thumb_path_is_relative_to_upload_dir(tmp_path):
    upload_dir = tmp_path / "uploads"
    source = _source_in(upload_dir)
    source.write_bytes(_make_jpeg(100, 100))

    result = ThumbnailService(upload_dir).generate(source, "image/jpeg")

    assert result is not None
    assert not result.startswith("/")
    assert "thumbnails" in result
    assert result.endswith("_thumb.jpg")


def test_thumb_landscape_maintains_aspect_ratio(tmp_path):
    upload_dir = tmp_path / "uploads"
    source = _source_in(upload_dir)
    source.write_bytes(_make_jpeg(600, 100))

    result = ThumbnailService(upload_dir).generate(source, "image/jpeg")

    assert result is not None
    with Image.open(upload_dir / result) as img:
        # 600x100 → scale 0.5 → 300x50 (exakt, Pillow thumbnail ist deterministisch)
        assert img.size == (300, 50)


def test_thumb_already_small_not_upscaled(tmp_path):
    upload_dir = tmp_path / "uploads"
    source = _source_in(upload_dir)
    source.write_bytes(_make_jpeg(50, 50))

    result = ThumbnailService(upload_dir).generate(source, "image/jpeg")

    assert result is not None
    with Image.open(upload_dir / result) as img:
        assert img.size == (50, 50)


# ---------------------------------------------------------------------------
# Fehlerbehandlung
# ---------------------------------------------------------------------------

def test_thumb_corrupt_image_returns_none(tmp_path):
    upload_dir = tmp_path / "uploads"
    source = _source_in(upload_dir)
    source.write_bytes(b"\xff\xd8\xff corrupt")

    result = ThumbnailService(upload_dir).generate(source, "image/jpeg")

    assert result is None


def test_thumb_no_orphan_dir_on_image_open_failure(tmp_path):
    """thumbnails/-Verzeichnis wird nicht angelegt wenn Pillow die Datei nicht öffnen kann."""
    upload_dir = tmp_path / "uploads"
    dest_dir = upload_dir / "device" / "2026-06-22"
    dest_dir.mkdir(parents=True)
    source = dest_dir / "abc123.jpg"
    source.write_bytes(b"not an image at all")

    ThumbnailService(upload_dir).generate(source, "image/jpeg")

    assert not (dest_dir / "thumbnails").exists()


def test_thumb_unsupported_mime_type_returns_none(tmp_path):
    upload_dir = tmp_path / "uploads"
    source = _source_in(upload_dir, "file.pdf")
    source.write_bytes(b"%PDF-1.4")

    result = ThumbnailService(upload_dir).generate(source, "application/pdf")

    assert result is None


def test_thumb_video_ffmpeg_not_found_returns_none(tmp_path, monkeypatch):
    monkeypatch.setattr("app.services.thumbnail.shutil.which", lambda _cmd: None)

    upload_dir = tmp_path / "uploads"
    source = _source_in(upload_dir, "vid.mp4")
    source.write_bytes(b"\x00\x00\x00\x1cftyp")

    result = ThumbnailService(upload_dir).generate(source, "video/mp4")

    assert result is None


def test_thumb_video_ffmpeg_error_returns_none(tmp_path, monkeypatch):
    upload_dir = tmp_path / "uploads"
    source = _source_in(upload_dir, "vid.mp4")
    source.write_bytes(b"\x00\x00\x00\x1cftyp")

    def _fake_run(*_args, **_kwargs):
        return subprocess.CompletedProcess(
            args=[], returncode=1, stderr=b"some ffmpeg error", stdout=b""
        )

    monkeypatch.setattr(subprocess, "run", _fake_run)

    result = ThumbnailService(upload_dir).generate(source, "video/mp4")

    assert result is None


def test_thumb_video_no_orphan_dir_on_ffmpeg_failure(tmp_path, monkeypatch):
    """thumbnails/-Verzeichnis wird bei ffmpeg-Fehler wieder entfernt."""
    upload_dir = tmp_path / "uploads"
    dest_dir = upload_dir / "device" / "2026-06-22"
    dest_dir.mkdir(parents=True)
    source = dest_dir / "vid.mp4"
    source.write_bytes(b"\x00\x00\x00\x1cftyp")

    def _fake_run(*_args, **_kwargs):
        return subprocess.CompletedProcess(
            args=[], returncode=1, stderr=b"error", stdout=b""
        )

    monkeypatch.setattr(subprocess, "run", _fake_run)

    ThumbnailService(upload_dir).generate(source, "video/mp4")

    assert not (dest_dir / "thumbnails").exists()
