from contextlib import asynccontextmanager

from fastapi import FastAPI

from app import APP_VERSION
from app.config import get_settings
from app.database import init_db
from app.routers import health


@asynccontextmanager
async def lifespan(_app: FastAPI):
    settings = get_settings()
    settings.upload_dir.mkdir(parents=True, exist_ok=True)
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    init_db()
    yield


app = FastAPI(
    title="Fotoserver-Koffer",
    version=APP_VERSION,
    lifespan=lifespan,
)

app.include_router(health.router, prefix="/api")
