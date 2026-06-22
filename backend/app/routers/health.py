import logging

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import text
from sqlmodel import Session

from app import APP_VERSION
from app.database import get_session

logger = logging.getLogger(__name__)

router = APIRouter(tags=["health"])


class HealthResponse(BaseModel):
    status: str
    version: str
    db: str


@router.get("/health", response_model=HealthResponse)
def health_check(session: Session = Depends(get_session)) -> HealthResponse:
    try:
        session.execute(text("SELECT 1"))
        db_status = "ok"
    except Exception:
        logger.exception("DB health check failed")
        db_status = "error"

    return HealthResponse(
        status="ok" if db_status == "ok" else "degraded",
        version=APP_VERSION,
        db=db_status,
    )
