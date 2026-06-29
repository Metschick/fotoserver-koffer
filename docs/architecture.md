# Architektur

Detaillierter Planungsdokument: [`plans/architektur-fotoserver-koffer.md`](../plans/architektur-fotoserver-koffer.md)

---

## Überblick

Der Fotoserver ist ein transportabler Offline-Dienst, der auf einem Raspberry Pi 5 läuft. Geräte im WLAN-Hotspot laden Fotos und Videos hoch und rufen die Galerie im Browser ab — ohne Internet, ohne Cloud.

```
Smartphone / Kamera
        │  WLAN-Hotspot (hostapd + dnsmasq)
        ▼
    Nginx (Port 80)
    ├── /          → Vue-3-SPA (statische Dateien aus dist/)
    └── /api/…     → FastAPI-Backend (uvicorn, Port 8000)
                        ├── SQLite-Datenbank  (data/fotoserver.db)
                        └── Dateisystem       (uploads/)
```

---

## Tech-Stack

| Schicht | Technologie | Begründung |
|---|---|---|
| Backend | FastAPI + Python 3.11 | ARM64-nativ, async, leichtgewichtig |
| Datenbank | SQLite (WAL-Modus) | Kein DB-Server, concurrent reads möglich |
| ORM | SQLModel | FastAPI-nativ, Pydantic-kompatibel |
| Thumbnails | Pillow (Bilder) + ffmpeg (Videos) | ffmpeg via apt auf Kali ARM64 verfügbar |
| MIME-Prüfung | python-magic | Magic-Byte-Prüfung statt HTTP-Header |
| Frontend | Vue 3 + Vite + Tailwind CSS | SPA, statische Ausgabe für Nginx |
| Reverse Proxy | Nginx | Statische Dateien + API-Proxy |
| Prozess-Manager | systemd | Kali-nativ, kein Autostart |
| Hotspot | hostapd + dnsmasq | Standard auf Kali/Pi |
| Deployment | pip + venv (kein Docker) | Ressourcenschonend für Pi + Powerbank |

---

## Backend-Module

### `app/config.py`
`Settings`-Klasse (pydantic-settings): liest `.env`, validiert `secret_key` (≥32 Zeichen, kein Default) und `log_level` (Whitelist). Alle Module beziehen Einstellungen über `get_settings()` (gecacht via `@lru_cache`).

### `app/database.py`
SQLite-Engine mit `journal_mode=WAL`, `busy_timeout=5000ms`, `foreign_keys=ON`. `get_session()` als Generator für FastAPI-Dependency-Injection.

### `app/models/media.py`
`Media`-SQLModel-Tabelle: UUID-Dateiname, Original-Dateiname (nur als Metadatum, nie als Pfad), MIME-Typ, Gerätename (Whitelist-Regex), Upload-Zeitstempel (UTC), relativer Thumbnail-Pfad. `GalleryPage`-Schema für paginierte Galerie-Antworten.

### `app/routers/upload.py`
`POST /api/upload`: Streaming-Read bis `max_bytes + 1` (verhindert Puffern großer Dateien), MIME-Prüfung via Magic Bytes, Disk-Space-Check, Speicherung via `StorageService`.

### `app/routers/gallery.py`
5 Endpunkte: paginierte Galerie, Album nach Gerät+Datum, Medien-Metadaten, Thumbnail als FileResponse, Original als FileResponse (mit `Content-Disposition: attachment`). Path-Traversal-Schutz via `.resolve() + is_relative_to()`.

### `app/services/storage.py`
Atomarer Schreibvorgang: `tempfile.mkstemp()` → Daten schreiben → `os.replace()`. DB-Rollback mit Datei-Cleanup bei Commit-Fehler. Ordnerstruktur: `uploads/Gerätename/YYYY-MM-DD/`.

### `app/services/thumbnail.py`
Synchrone Generierung nach jedem Upload. Bilder: Pillow (EXIF-Transpose, RGB-Konvertierung, max 300×300, LANCZOS). Videos: ffmpeg-Subprocess (erster Frame). Fehler werden abgefangen — `thumb_path` kann `null` sein, Upload bleibt trotzdem 201.

---

## Sicherheitsentscheidungen

| Bereich | Entscheidung |
|---|---|
| Dateinamen | Ausschließlich UUID4 + sanitierte Erweiterung (aus MIME-Mapping) |
| Original-Dateiname | Nur als DB-Metadatum, nie als Dateipfad verwendet |
| MIME-Prüfung | Server-seitig via Magic Bytes (python-magic), HTTP-Header ignoriert |
| Gerätename | Whitelist-Regex `^[a-zA-Z0-9_-]{1,50}$` als Pydantic-Validator im Model |
| Path-Traversal | Alle DB-abgeleiteten Pfade via `.resolve() + is_relative_to()` validiert |
| Upload-Limit | 100 MB pro Datei + Disk-Free-Space-Check vor Schreiben |
| `secret_key` | Pflichtfeld, min. 32 Zeichen, kein Default — Validator wirft bei `CHANGE_ME` |
| Nginx-Headers | `X-Content-Type-Options`, `X-Frame-Options`, CSP, `Referrer-Policy` |
| hostapd.conf | `chmod 600 root:root` auf dem Pi; `ap_isolate=1` (Clients isoliert) |
| Authentifizierung | V1: WLAN-Passwort als einzige Zugangsschranke (kein Web-Login) |

---

## Dateistruktur auf dem Pi

```
/opt/fotoserver/
├── backend/
│   └── app/
├── frontend/
│   └── dist/               ← statische Dateien (Build-Artefakt aus CI)
├── deploy/
│   ├── nginx/
│   ├── scripts/
│   ├── systemd/
│   └── hotspot/
├── uploads/                ← Nutzerdaten (nicht in Git)
│   └── GeräteName/
│       └── YYYY-MM-DD/
│           ├── <uuid>.jpg
│           └── thumbnails/
│               └── <uuid>_thumb.jpg
├── data/
│   └── fotoserver.db       ← SQLite-Datenbank (WAL)
├── backups/                ← Backup-Archive
├── .env                    ← Konfiguration (nicht in Git, chmod 600)
└── .venv/
```

---

## systemd-Dienste

| Unit | Funktion |
|---|---|
| `fotoserver.target` | Gruppen-Target — startet/stoppt alle vier Dienste gemeinsam |
| `fotoserver-api.service` | FastAPI-Backend (uvicorn, User `fotoserver`) |
| `fotoserver-wlan0.service` | Setzt statische IP vor hostapd-Start (Oneshot) |
| `hostapd.service` | WLAN-Access-Point |
| `dnsmasq.service` | DHCP + Captive-DNS (alle Domains → Pi) |
| `nginx.service` | Reverse Proxy + statische Dateien |
| `fotoserver-backup.service` | Manueller/Timer-gesteuerter Backup (Oneshot) |
| `fotoserver-backup.timer` | Tägliche Sicherung um 02:00 (optional) |

**Start-Reihenfolge:** `fotoserver-wlan0` → `hostapd` → `dnsmasq` → `fotoserver-api` → `nginx`

`fotoserver.target` wird nicht aktiviert — kein Autostart beim Booten. Start und Stop erfolgen manuell via `fotoserver-start.sh` / `fotoserver-stop.sh`.

---

## Frontend-Build-Strategie

- Entwicklung: Vite Dev-Server mit API-Proxy auf Backend
- Produktion: `npm run build` → `dist/` → GitHub-Release-Artefakt
- Deployment: `install.sh` lädt `dist/` vom GitHub-Release — kein Node.js auf dem Pi nötig
