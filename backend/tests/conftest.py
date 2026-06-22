from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event as sa_event
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool

from app.config import Settings, get_settings
from app.database import get_session
from app.main import app
from tests.constants import TEST_SECRET_KEY


def _configure_test_sqlite(dbapi_conn, _record) -> None:
    cursor = dbapi_conn.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


@pytest.fixture(name="session")
def session_fixture():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    sa_event.listen(engine, "connect", _configure_test_sqlite)
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session


@pytest.fixture(name="upload_dir")
def upload_dir_fixture(tmp_path: Path) -> Path:
    d = tmp_path / "uploads"
    d.mkdir()
    return d


@pytest.fixture(name="test_settings")
def test_settings_fixture(upload_dir: Path, tmp_path: Path) -> Settings:
    return Settings(
        secret_key=TEST_SECRET_KEY,
        upload_dir=upload_dir,
        data_dir=tmp_path / "data",
    )


@pytest.fixture(name="client")
def client_fixture(session: Session, test_settings: Settings):
    def override_session():
        yield session

    app.dependency_overrides[get_session] = override_session
    app.dependency_overrides[get_settings] = lambda: test_settings
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()
