import logging

from fastapi import APIRouter, Depends, Form, HTTPException, UploadFile
from sqlmodel import Session

from app.config import Settings, get_settings
from app.database import get_session
from app.exceptions import FileTooLargeError, UnsupportedMediaTypeError
from app.models.media import MediaRead
from app.services.storage import StorageService
from app.services.thumbnail import ThumbnailService
from app.utils.file_utils import check_disk_space, validate_device_name

logger = logging.getLogger(__name__)

router = APIRouter(tags=["upload"])


@router.post("/upload", response_model=MediaRead, status_code=201)
async def upload_file(
    file: UploadFile,
    device_name: str = Form(...),
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> MediaRead:
    try:
        validate_device_name(device_name)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    try:
        check_disk_space(settings.upload_dir, settings.disk_min_free_gb)
    except OSError as exc:
        logger.error("Disk space check failed: %s", exc)
        raise HTTPException(status_code=507, detail=str(exc)) from exc

    # Streaming-Schreibvorgang: die Datei wird in Chunks direkt auf die Platte
    # geschrieben (nie vollständig als bytes im RAM gehalten), damit auch
    # Uploads im GB-Bereich auf dem Raspberry Pi verarbeitet werden können.
    storage = StorageService(settings.upload_dir)
    try:
        media = await storage.save_stream(
            file=file,
            original_filename=file.filename or "unknown",
            device_name=device_name,
            allowed_mime_types=settings.allowed_mime_types,
            max_bytes=settings.max_file_size_bytes,
            disk_min_free_gb=settings.disk_min_free_gb,
            session=session,
        )
    except UnsupportedMediaTypeError as exc:
        raise HTTPException(status_code=415, detail=str(exc)) from exc
    except FileTooLargeError as exc:
        raise HTTPException(status_code=413, detail=str(exc)) from exc
    except OSError as exc:
        logger.error("Disk space check failed during streaming: %s", exc)
        raise HTTPException(status_code=507, detail=str(exc)) from exc
    logger.info(
        "Uploaded %s (%d B) from device %r",
        media.stored_as,
        media.size_bytes,
        device_name,
    )

    source_path = settings.upload_dir / media.album_path / media.stored_as
    thumb_rel = ThumbnailService(settings.upload_dir).generate(source_path, media.mime_type)
    if thumb_rel:
        media.thumb_path = thumb_rel
        session.add(media)
        session.commit()
        session.refresh(media)

    return MediaRead.from_media(media)
