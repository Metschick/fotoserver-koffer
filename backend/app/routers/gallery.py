import logging
from datetime import date as date_type
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse
from sqlalchemy import func
from sqlmodel import Session, col, select

from app.config import Settings, get_settings
from app.database import get_session
from app.models.media import GalleryPage, Media, MediaRead
from app.utils.file_utils import validate_device_name

logger = logging.getLogger(__name__)
router = APIRouter(tags=["gallery"])


def _assert_within_upload_dir(path: Path, upload_dir: Path, media_id: int) -> None:
    """Schützt vor Path-Traversal: Pfad muss innerhalb upload_dir liegen."""
    if not path.is_relative_to(upload_dir.resolve()):
        logger.error("File path escapes upload_dir for media id=%d: %s", media_id, path)
        raise HTTPException(status_code=500, detail="Internal storage error")


@router.get("/gallery", response_model=GalleryPage)
def list_gallery(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    session: Session = Depends(get_session),
) -> GalleryPage:
    total = session.exec(select(func.count(col(Media.id))).select_from(Media)).one()
    items = session.exec(
        select(Media)
        .order_by(col(Media.uploaded_at).desc(), col(Media.id).desc())
        .limit(limit)
        .offset(offset)
    ).all()
    return GalleryPage(
        items=[MediaRead.from_media(m) for m in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/gallery/{device_name}/{date_str}", response_model=GalleryPage)
def list_album(
    device_name: str,
    date_str: str,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    session: Session = Depends(get_session),
) -> GalleryPage:
    try:
        validate_device_name(device_name)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    try:
        parsed_date = date_type.fromisoformat(date_str)
    except ValueError as exc:
        raise HTTPException(
            status_code=422, detail=f"Invalid date {date_str!r}, expected YYYY-MM-DD"
        ) from exc

    day_start = datetime(
        parsed_date.year, parsed_date.month, parsed_date.day, tzinfo=timezone.utc
    )
    day_end = day_start + timedelta(days=1)

    where = [
        Media.device_name == device_name,
        col(Media.uploaded_at) >= day_start,
        col(Media.uploaded_at) < day_end,
    ]

    total = session.exec(
        select(func.count(col(Media.id))).where(*where)
    ).one()
    items = session.exec(
        select(Media)
        .where(*where)
        .order_by(col(Media.uploaded_at).asc(), col(Media.id).asc())
        .limit(limit)
        .offset(offset)
    ).all()

    return GalleryPage(
        items=[MediaRead.from_media(m) for m in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/media/{media_id}", response_model=MediaRead)
def get_media(
    media_id: int,
    session: Session = Depends(get_session),
) -> MediaRead:
    media = session.get(Media, media_id)
    if media is None:
        raise HTTPException(status_code=404, detail="Media not found")
    return MediaRead.from_media(media)


@router.get(
    "/media/{media_id}/thumb",
    response_class=FileResponse,
    responses={404: {"description": "Media or thumbnail not found"}},
)
def get_thumb(
    media_id: int,
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> FileResponse:
    media = session.get(Media, media_id)
    if media is None:
        raise HTTPException(status_code=404, detail="Media not found")
    if media.thumb_path is None:
        raise HTTPException(status_code=404, detail="No thumbnail available")

    thumb_file = (settings.upload_dir / media.thumb_path).resolve()
    _assert_within_upload_dir(thumb_file, settings.upload_dir, media_id)

    if not thumb_file.is_file():
        logger.warning("Thumbnail missing on disk for media id=%d: %s", media_id, thumb_file)
        raise HTTPException(status_code=404, detail="Thumbnail not found on disk")

    return FileResponse(thumb_file, media_type="image/jpeg")


@router.get(
    "/media/{media_id}/file",
    response_class=FileResponse,
    responses={404: {"description": "Media or file not found"}},
)
def get_file(
    media_id: int,
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> FileResponse:
    media = session.get(Media, media_id)
    if media is None:
        raise HTTPException(status_code=404, detail="Media not found")

    file_path = (settings.upload_dir / media.album_path / media.stored_as).resolve()
    _assert_within_upload_dir(file_path, settings.upload_dir, media_id)

    if not file_path.is_file():
        logger.warning("Original file missing on disk for media id=%d: %s", media_id, file_path)
        raise HTTPException(status_code=404, detail="File not found on disk")

    # Content-Disposition: attachment verhindert Browser-Inline-Ausführung
    return FileResponse(file_path, media_type=media.mime_type, filename=media.stored_as)
