"""
Tests für den globalen Exception-Handler und den ValidationError-Handler in main.py.
"""

import logging

import pytest
from fastapi import APIRouter
from fastapi.testclient import TestClient

from app.config import get_settings
from app.database import get_session
from app.main import app as fastapi_app


@pytest.fixture(name="error_route")
def error_route_fixture():
    """Registriert eine temporäre Route, die einen unbehandelten Fehler wirft."""
    router = APIRouter()

    @router.get("/_test_crash")
    async def _crash() -> None:
        raise RuntimeError("Simulierter unbehandelter Fehler")

    fastapi_app.include_router(router)
    yield
    # Route nach dem Test entfernen, damit sie andere Tests nicht beeinflusst
    fastapi_app.routes[:] = [
        r for r in fastapi_app.routes
        if not (hasattr(r, "path") and r.path == "/_test_crash")
    ]
    # OpenAPI-Schema-Cache zurücksetzen, damit nachfolgende Tests keinen veralteten
    # Zustand sehen (include_router aktualisiert routes, nicht den gecachten Schema-Dict).
    fastapi_app.openapi_schema = None


@pytest.fixture(name="crash_client")
def crash_client_fixture(session, test_settings):
    """TestClient mit raise_server_exceptions=False für den Exception-Handler-Test.

    Starlette's ServerErrorMiddleware sendet die 500-Antwort, re-raisiert aber
    danach immer. raise_server_exceptions=False lässt den TestClient die gesendete
    Antwort zurückgeben statt die re-raisierte Exception zu propagieren.
    """
    def override_session():
        yield session

    fastapi_app.dependency_overrides[get_session] = override_session
    fastapi_app.dependency_overrides[get_settings] = lambda: test_settings
    with TestClient(fastapi_app, raise_server_exceptions=False) as c:
        yield c
    fastapi_app.dependency_overrides.clear()


# ── Unbehandelter Exception-Handler ────────────────────────────────────────

def test_unhandled_exception_returns_500(crash_client, error_route):
    response = crash_client.get("/_test_crash")
    assert response.status_code == 500


def test_unhandled_exception_hides_traceback(crash_client, error_route):
    response = crash_client.get("/_test_crash")
    body = response.json()
    assert body == {"detail": "Internal server error"}
    # Kein Traceback oder Klassen-Name darf nach außen dringen
    assert "RuntimeError" not in response.text
    assert "Traceback" not in response.text
    assert "Simulierter" not in response.text


def test_unhandled_exception_is_logged(crash_client, error_route, caplog):
    with caplog.at_level(logging.ERROR):
        crash_client.get("/_test_crash")
    messages = [r.getMessage() for r in caplog.records]
    assert any("Unbehandelter Fehler" in m for m in messages)


def test_unhandled_exception_log_contains_method_and_path(crash_client, error_route, caplog):
    with caplog.at_level(logging.ERROR):
        crash_client.get("/_test_crash")
    combined = " ".join(r.getMessage() for r in caplog.records)
    assert "GET" in combined
    assert "/_test_crash" in combined


# ── Validierungsfehler-Handler ──────────────────────────────────────────────

def test_validation_error_returns_422(client):
    # POST ohne Pflichtfelder (file + device_name)
    response = client.post("/api/upload")
    assert response.status_code == 422


def test_validation_error_body_format(client):
    response = client.post("/api/upload")
    body = response.json()
    assert "detail" in body
    assert isinstance(body["detail"], list)
    assert len(body["detail"]) > 0


def test_validation_error_is_logged(client, caplog):
    with caplog.at_level(logging.WARNING):
        client.post("/api/upload")
    messages = [r.getMessage() for r in caplog.records]
    assert any("Validierungsfehler" in m for m in messages)


# ── HTTPException bleibt erhalten (nicht vom catch-all übernommen) ──────────

def test_http_404_not_swallowed_by_catch_all(client):
    response = client.get("/api/media/99999")
    assert response.status_code == 404


def test_http_404_body(client):
    response = client.get("/api/media/99999")
    body = response.json()
    assert "detail" in body
    assert body["detail"] == "Media not found"
