# Entwicklungsumgebung

Entwicklung läuft auf einem PC unter WSL oder nativem Linux. Der Pi wird erst beim Deployment benötigt.

---

## Voraussetzungen

- Python 3.11+
- Node.js 20+ (für das Frontend)
- `libmagic1` (MIME-Erkennung): `sudo apt install libmagic1`
- `ffmpeg` (Video-Thumbnails, optional für Tests): `sudo apt install ffmpeg`

---

## Backend

### Einrichten

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
```

### Starten (Entwicklungsserver)

```bash
# .env anlegen (falls noch nicht vorhanden)
cp .env.example .env
# SECRET_KEY setzen:
python3 -c "import secrets; print('SECRET_KEY=' + secrets.token_hex(32))" >> .env

source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API erreichbar unter `http://localhost:8000`  
OpenAPI-Dokumentation: `http://localhost:8000/docs`

### Tests

```bash
cd backend
source .venv/bin/activate

# Alle Tests
pytest

# Mit Coverage-Report
pytest --cov=app --cov-report=term-missing

# Einzelne Testdatei
pytest tests/test_upload.py -v

# Linter
ruff check app/ tests/
```

### Teststrategie

| Testdatei | Abgedeckte Komponente | Anzahl Tests |
|---|---|---|
| `test_health.py` | `GET /api/health` (Status + Body) | 2 |
| `test_upload.py` | `POST /api/upload` (Erfolg, Fehler, Grenzwerte) | 15 |
| `test_thumbnail.py` | `ThumbnailService` (Bilder, Videos, Fehler) | 11 |
| `test_gallery.py` | Gallery-API (5 Endpunkte, Pagination, Sortierung) | 20 |
| `test_exception_handler.py` | Exception-Handler (500, 422, 404) | 9 |
| `test_config.py` | Settings-Validatoren (secret_key, log_level) | 8 |

Tests laufen gegen eine In-Memory-SQLite-Datenbank (`dependency_overrides`). Kein Netzwerk, kein Dateisystem-Schreibzugriff außerhalb von `tmp_path`.

---

## Frontend

### Einrichten

```bash
cd frontend
npm install
```

### Entwicklungsserver

```bash
npm run dev
```

Erreichbar unter `http://localhost:5173`  
API-Anfragen werden via Vite-Proxy auf `http://localhost:8000` weitergeleitet — Backend muss parallel laufen.

### Build

```bash
npm run build        # Produktions-Build nach dist/
npm run type-check   # TypeScript-Typprüfung (vue-tsc)
```

---

## Projektstruktur

```
fotoserver-koffer/
├── backend/
│   ├── app/
│   │   ├── config.py          # Einstellungen (pydantic-settings, Validatoren)
│   │   ├── database.py        # SQLite-Engine + Session-Generator
│   │   ├── logging_config.py  # Logging-Konfiguration
│   │   ├── main.py            # FastAPI-App, Lifespan, Exception-Handler
│   │   ├── models/
│   │   │   └── media.py       # SQLModel Media-Tabelle + Read-Schemas
│   │   ├── routers/
│   │   │   ├── health.py      # GET /api/health
│   │   │   ├── upload.py      # POST /api/upload
│   │   │   └── gallery.py     # Galerie- und Medien-Endpunkte
│   │   ├── services/
│   │   │   ├── storage.py     # Atomares Dateispeichern + DB-Commit
│   │   │   └── thumbnail.py   # Pillow (Bilder) + ffmpeg (Videos)
│   │   └── utils/
│   │       └── file_utils.py  # MIME-Prüfung, Gerätenamens-Validierung
│   ├── tests/
│   │   ├── conftest.py        # In-Memory-DB, Test-Settings, Fixtures
│   │   └── test_*.py
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   └── pyproject.toml
├── frontend/
│   ├── src/
│   │   ├── api/               # API-Client-Funktionen
│   │   ├── components/        # Vue-Komponenten (NavBar, UploadForm, GalleryGrid …)
│   │   ├── composables/       # useTheme
│   │   ├── router/            # Vue Router
│   │   └── views/             # HomeView, UploadView, GalleryView
│   └── public/
│       └── theme-init.js      # FOUC-Schutz (synchrones Theme-Init-Skript)
├── deploy/
│   ├── hotspot/               # hostapd + dnsmasq Templates
│   ├── nginx/                 # Nginx-Konfiguration
│   ├── scripts/               # Setup- und Steuer-Skripte
│   └── systemd/               # Service-Units + Drop-ins + Timer
├── docs/
├── plans/
├── .env.example
└── CLAUDE.md
```

---

## Häufige Probleme

**`ImportError: failed to find libmagic`**  
→ `sudo apt install libmagic1`

**`pytest: command not found`**  
→ venv aktivieren: `source .venv/bin/activate`

**Frontend-API-Fehler (CORS / Connection Refused)**  
→ Backend muss auf Port 8000 laufen; Vite-Proxy leitet `/api` automatisch weiter.

**`SECRET_KEY` Validator-Fehler beim Start**  
→ In `.env` muss `SECRET_KEY` auf einen zufälligen Wert ≥ 32 Zeichen gesetzt sein.  
→ Generieren: `python3 -c "import secrets; print(secrets.token_hex(32))"`
