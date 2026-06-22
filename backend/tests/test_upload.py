from pathlib import Path

from fastapi.testclient import TestClient
from sqlmodel import Session

from app.config import Settings, get_settings
from app.database import get_session
from app.main import app
from tests.constants import TEST_SECRET_KEY

# Minimale JPEG-Bytes (ausreichend für python-magic zur Erkennung als image/jpeg)
MINIMAL_JPEG = bytes([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
])


def _make_client(session: Session, upload_dir: Path, tmp_path: Path, **overrides):
    """Erstellt TestClient mit benutzerdefinierten Settings."""
    settings = Settings(
        secret_key=TEST_SECRET_KEY,
        upload_dir=upload_dir,
        data_dir=tmp_path / "data",
        **overrides,
    )

    def override_session():
        yield session

    app.dependency_overrides[get_session] = override_session
    app.dependency_overrides[get_settings] = lambda: settings
    return TestClient(app)


def _clear():
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Erfolgreicher Upload
# ---------------------------------------------------------------------------

def test_upload_returns_201(client):
    resp = client.post(
        "/api/upload",
        files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
        data={"device_name": "iPhone-Anna"},
    )
    assert resp.status_code == 201


def test_upload_response_body(client):
    resp = client.post(
        "/api/upload",
        files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
        data={"device_name": "iPhone-Anna"},
    )
    body = resp.json()
    assert body["filename"] == "foto.jpg"
    assert body["mime_type"] == "image/jpeg"
    assert body["size_bytes"] == len(MINIMAL_JPEG)
    assert body["device_name"] == "iPhone-Anna"
    assert body["album_path"].startswith("iPhone-Anna/")
    assert body["id"] is not None


def test_upload_file_saved_to_disk(client, upload_dir):
    client.post(
        "/api/upload",
        files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
        data={"device_name": "Samsung-Galaxy"},
    )
    device_dirs = list((upload_dir / "Samsung-Galaxy").glob("*/"))
    assert len(device_dirs) == 1, "Genau ein Datumsordner erwartet"
    saved_files = list(device_dirs[0].glob("*"))
    assert len(saved_files) == 1
    assert saved_files[0].read_bytes() == MINIMAL_JPEG


def test_upload_stored_as_uses_uuid(client, upload_dir):
    client.post(
        "/api/upload",
        files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
        data={"device_name": "test-device"},
    )
    saved = list(upload_dir.glob("test-device/**/*.jpg"))
    assert len(saved) == 1
    # Dateiname auf Disk ist UUID-basiert – enthält niemals den Originalnamen
    assert "foto" not in saved[0].name
    assert saved[0].suffix == ".jpg"


# ---------------------------------------------------------------------------
# Fehlerbehandlung
# ---------------------------------------------------------------------------

def test_upload_invalid_mime_type(client):
    resp = client.post(
        "/api/upload",
        files={"file": ("file.txt", b"This is plain text, not an image.", "text/plain")},
        data={"device_name": "test-device"},
    )
    assert resp.status_code == 415


def test_upload_empty_file_rejected(client):
    # Leere Datei hat keinen erkennbaren MIME-Typ → 415
    resp = client.post(
        "/api/upload",
        files={"file": ("empty.jpg", b"", "image/jpeg")},
        data={"device_name": "test-device"},
    )
    assert resp.status_code == 415


def test_upload_file_too_large(session, upload_dir, tmp_path):
    c = _make_client(session, upload_dir, tmp_path, max_file_size_mb=0)
    try:
        with c:
            resp = c.post(
                "/api/upload",
                files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
                data={"device_name": "test-device"},
            )
        assert resp.status_code == 413
    finally:
        _clear()


def test_upload_invalid_device_name(client):
    resp = client.post(
        "/api/upload",
        files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
        data={"device_name": "../../../etc/passwd"},
    )
    assert resp.status_code == 422


def test_upload_device_name_with_spaces(client):
    resp = client.post(
        "/api/upload",
        files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
        data={"device_name": "mein gerät"},
    )
    assert resp.status_code == 422


def test_upload_device_name_max_length_valid(client):
    resp = client.post(
        "/api/upload",
        files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
        data={"device_name": "a" * 50},
    )
    assert resp.status_code == 201


def test_upload_device_name_too_long(client):
    resp = client.post(
        "/api/upload",
        files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
        data={"device_name": "a" * 51},
    )
    assert resp.status_code == 422


def test_upload_missing_device_name(client):
    resp = client.post(
        "/api/upload",
        files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
    )
    assert resp.status_code == 422


def test_upload_valid_jpeg_sets_thumb_path(client, valid_jpeg, upload_dir):
    resp = client.post(
        "/api/upload",
        files={"file": ("photo.jpg", valid_jpeg, "image/jpeg")},
        data={"device_name": "test-device"},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["thumb_path"] is not None
    assert (upload_dir / body["thumb_path"]).exists()


def test_upload_disk_full(client, monkeypatch):
    def _raise_disk_full(*_args, **_kwargs):
        raise OSError("Disk full")

    monkeypatch.setattr("app.routers.upload.check_disk_space", _raise_disk_full)
    resp = client.post(
        "/api/upload",
        files={"file": ("foto.jpg", MINIMAL_JPEG, "image/jpeg")},
        data={"device_name": "test-device"},
    )
    assert resp.status_code == 507
