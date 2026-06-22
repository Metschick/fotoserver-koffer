import io
from datetime import datetime, timezone

from PIL import Image

from app.models.media import Media


def _make_jpeg(width: int = 50, height: int = 50) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (width, height), (100, 150, 200)).save(buf, format="JPEG")
    return buf.getvalue()


def _upload(client, device_name: str = "test-device") -> dict:
    resp = client.post(
        "/api/upload",
        files={"file": ("photo.jpg", _make_jpeg(), "image/jpeg")},
        data={"device_name": device_name},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


def _today_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


# ---------------------------------------------------------------------------
# GET /api/gallery
# ---------------------------------------------------------------------------

def test_gallery_empty(client):
    resp = client.get("/api/gallery")
    assert resp.status_code == 200
    body = resp.json()
    assert body["items"] == []
    assert body["total"] == 0
    assert body["limit"] == 50
    assert body["offset"] == 0


def test_gallery_returns_uploaded_items(client):
    _upload(client, "device-one")
    _upload(client, "device-two")

    resp = client.get("/api/gallery")
    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 2
    assert len(body["items"]) == 2


def test_gallery_newest_first(client):
    _upload(client, "test-device")
    second = _upload(client, "test-device")

    resp = client.get("/api/gallery")
    items = resp.json()["items"]
    # Neuestes Bild zuerst
    assert items[0]["id"] == second["id"]


def test_gallery_pagination_limit(client):
    for _ in range(3):
        _upload(client)

    resp = client.get("/api/gallery?limit=2")
    body = resp.json()
    assert body["total"] == 3
    assert len(body["items"]) == 2
    assert body["limit"] == 2


def test_gallery_pagination_offset(client):
    for _ in range(3):
        _upload(client)

    resp = client.get("/api/gallery?limit=10&offset=2")
    body = resp.json()
    assert body["total"] == 3
    assert len(body["items"]) == 1
    assert body["offset"] == 2


def test_gallery_items_contain_thumb_path(client):
    item = _upload(client)
    resp = client.get("/api/gallery")
    items = resp.json()["items"]
    assert items[0]["thumb_path"] == item["thumb_path"]


# ---------------------------------------------------------------------------
# GET /api/gallery/{device_name}/{date}
# ---------------------------------------------------------------------------

def test_gallery_album_returns_correct_device(client):
    _upload(client, "device-one")
    _upload(client, "device-two")
    _upload(client, "device-two")

    today = _today_utc()
    resp = client.get(f"/api/gallery/device-two/{today}")
    body = resp.json()
    assert body["total"] == 2
    assert all(i["device_name"] == "device-two" for i in body["items"])


def test_gallery_album_empty_for_unknown_device(client):
    _upload(client, "known-device")

    today = _today_utc()
    resp = client.get(f"/api/gallery/unknown-device/{today}")
    assert resp.status_code == 200
    assert resp.json()["total"] == 0


def test_gallery_album_items_sorted_oldest_first(client):
    first = _upload(client, "test-device")
    second = _upload(client, "test-device")

    today = _today_utc()
    resp = client.get(f"/api/gallery/test-device/{today}")
    items = resp.json()["items"]
    # Sekundärsortierung nach id garantiert Determinismus bei gleicher uploaded_at
    assert items[0]["id"] == first["id"]
    assert items[1]["id"] == second["id"]


def test_gallery_album_invalid_device_name(client):
    # Punkt ist URL-sicher, aber nicht im Whitelist ^[a-zA-Z0-9_-]{1,50}$
    resp = client.get("/api/gallery/invalid.device/2026-06-22")
    assert resp.status_code == 422


def test_gallery_album_invalid_date(client):
    resp = client.get("/api/gallery/test-device/not-a-date")
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# GET /api/media/{id}
# ---------------------------------------------------------------------------

def test_get_media_by_id(client):
    item = _upload(client, "test-device")

    resp = client.get(f"/api/media/{item['id']}")
    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == item["id"]
    assert body["filename"] == "photo.jpg"
    assert body["mime_type"] == "image/jpeg"
    assert body["device_name"] == "test-device"
    assert "album_path" in body
    assert "thumb_path" in body


def test_get_media_not_found(client):
    resp = client.get("/api/media/99999")
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# GET /api/media/{id}/thumb
# ---------------------------------------------------------------------------

def test_get_thumb_returns_jpeg(client):
    item = _upload(client)
    assert item["thumb_path"] is not None

    resp = client.get(f"/api/media/{item['id']}/thumb")
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("image/jpeg")
    # Antwort enthält JPEG-Daten
    assert resp.content[:2] == b"\xff\xd8"


def test_get_thumb_not_found_id(client):
    resp = client.get("/api/media/99999/thumb")
    assert resp.status_code == 404


def test_get_thumb_no_thumb_path(client, session):
    # Direkter DB-Insert nötig: normaler Upload würde immer einen thumb_path setzen
    media = Media(
        filename="test.jpg",
        stored_as="no_thumb.jpg",
        mime_type="image/jpeg",
        size_bytes=100,
        device_name="test-device",
        uploaded_at=datetime.now(timezone.utc),
        thumb_path=None,
    )
    session.add(media)
    session.commit()
    session.refresh(media)

    resp = client.get(f"/api/media/{media.id}/thumb")
    assert resp.status_code == 404
    assert "thumbnail" in resp.json()["detail"].lower()


# ---------------------------------------------------------------------------
# GET /api/media/{id}/file
# ---------------------------------------------------------------------------

def test_get_file_returns_content(client):
    item = _upload(client)

    resp = client.get(f"/api/media/{item['id']}/file")
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("image/jpeg")
    # Antwort enthält die originalen JPEG-Daten
    assert resp.content[:2] == b"\xff\xd8"
    assert len(resp.content) == item["size_bytes"]


def test_get_file_not_found_id(client):
    resp = client.get("/api/media/99999/file")
    assert resp.status_code == 404


def test_get_thumb_file_missing_on_disk(client, session):
    # thumb_path gesetzt, aber Datei existiert nicht auf Disk
    media = Media(
        filename="ghost.jpg",
        stored_as="ghost_abc123.jpg",
        mime_type="image/jpeg",
        size_bytes=100,
        device_name="test-device",
        uploaded_at=datetime.now(timezone.utc),
        thumb_path="test-device/2026-06-22/thumbnails/ghost_abc123_thumb.jpg",
    )
    session.add(media)
    session.commit()
    session.refresh(media)

    resp = client.get(f"/api/media/{media.id}/thumb")
    assert resp.status_code == 404


def test_get_file_missing_on_disk(client, session):
    # DB-Eintrag vorhanden, aber Originaldatei wurde gelöscht
    media = Media(
        filename="ghost.jpg",
        stored_as="ghost_original.jpg",
        mime_type="image/jpeg",
        size_bytes=100,
        device_name="test-device",
        uploaded_at=datetime.now(timezone.utc),
        thumb_path=None,
    )
    session.add(media)
    session.commit()
    session.refresh(media)

    resp = client.get(f"/api/media/{media.id}/file")
    assert resp.status_code == 404
