import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app import APP_VERSION
from app.config import get_settings
from app.database import init_db
from app.logging_config import configure_logging
from app.routers import gallery, health, upload

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    settings = get_settings()
    configure_logging(settings.log_level)
    settings.upload_dir.mkdir(parents=True, exist_ok=True)
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    init_db()
    logger.info(
        "Fotoserver-Koffer %s gestartet (upload_dir=%s, log_level=%s)",
        APP_VERSION,
        settings.upload_dir,
        settings.log_level,
    )
    yield
    logger.info("Fotoserver-Koffer wird beendet.")


app = FastAPI(
    title="Fotoserver-Koffer",
    version=APP_VERSION,
    lifespan=lifespan,
)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    logger.warning(
        "Validierungsfehler %s %s: %s",
        request.method,
        request.url.path,
        exc.errors(),
    )
    return JSONResponse(status_code=422, content={"detail": exc.errors()})


@app.exception_handler(Exception)
async def unhandled_exception_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    logger.exception(
        "Unbehandelter Fehler %s %s",
        request.method,
        request.url.path,
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )


app.include_router(health.router, prefix="/api")
app.include_router(upload.router, prefix="/api")
app.include_router(gallery.router, prefix="/api")
