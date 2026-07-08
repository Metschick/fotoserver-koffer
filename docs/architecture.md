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
`Settings`-Klasse (pydantic-settings): liest `.env`, validiert `secret_key` (≥32 Zeichen, kein Default) und `log_level` (Whitelist). Alle Module beziehen Einstellungen über `get_settings()` (gecacht via `@lru_cache`). `extra="ignore"`, da dieselbe `.env`-Datei auch `HOTSPOT_*`/`FOTOSERVER_BACKUP_*`-Werte enthält, die ausschließlich von den Shell-Skripten gelesen werden (siehe [docs/deployment.md](deployment.md#konfiguration-env)). `env_file` wird nur gesetzt, wenn `.env` für den aktuellen Prozess lesbar ist — in Produktion (`chmod 600 root:root`) übernimmt systemd die Werte bereits als Umgebungsvariablen (`EnvironmentFile=`), der `fotoserver`-Prozess selbst darf die Datei nie öffnen.

### `app/database.py`
SQLite-Engine mit `journal_mode=WAL`, `busy_timeout=5000ms`, `foreign_keys=ON`. `get_session()` als Generator für FastAPI-Dependency-Injection.

### `app/models/media.py`
`Media`-SQLModel-Tabelle: UUID-Dateiname, Original-Dateiname (nur als Metadatum, nie als Pfad), MIME-Typ, Gerätename (Whitelist-Regex), Upload-Zeitstempel (UTC), relativer Thumbnail-Pfad. `GalleryPage`-Schema für paginierte Galerie-Antworten.

### `app/routers/upload.py`
`POST /api/upload`: delegiert das eigentliche Schreiben an `StorageService.save_stream()` (Chunk-Streaming, siehe unten), fängt `UnsupportedMediaTypeError` (415), `FileTooLargeError` (413) und `OSError` (507, Plattenplatz) ab und übersetzt sie in HTTP-Statuscodes.

### `app/routers/gallery.py`
5 Endpunkte: paginierte Galerie, Album nach Gerät+Datum, Medien-Metadaten, Thumbnail als FileResponse, Original als FileResponse (mit `Content-Disposition: attachment`). Path-Traversal-Schutz via `.resolve() + is_relative_to()`. `FileResponse` streamt beide Endpunkte direkt von der Platte (kein Volllesen in den RAM), unabhängig von der Dateigröße.

### `app/services/storage.py`
`StorageService.save_stream()` liest die Upload-Datei in 4-MiB-Chunks (`UPLOAD_CHUNK_SIZE`, siehe `app/utils/file_utils.py`) und schreibt jeden Chunk sofort per `os.write()` auf die Platte — die Datei liegt nie vollständig als `bytes`-Objekt im RAM. MIME-Erkennung (Magic Bytes) läuft auf dem ersten Chunk (`MIME_SNIFF_BYTES = 4096`), bevor überhaupt ein Verzeichnis angelegt wird. Die Temp-Datei liegt während des Schreibens in `uploads/.upload-tmp/` (nicht im Geräte/Datum-Ordner) — wird ein Upload während des Streamings abgelehnt (zu groß, Platte voll), bleibt kein leerer Ordner zurück. Bei Erfolg: atomarer `os.replace()` nach `uploads/Gerätename/YYYY-MM-DD/`. Während des Streamings wird der Plattenplatz nach jedem Chunk erneut geprüft (nicht nur einmal vorab), damit ein einzelner GB-Upload die Platte nicht vollständig füllen kann, bevor das Größenlimit greift.

#### Upload-Limit ändern

Das Limit ist auf 10 GB (10240 MB) pro Datei ausgelegt. Es wird an **zwei** Stellen durchgesetzt und muss bei Änderung an beiden konsistent angepasst werden:

1. **Backend** — `MAX_FILE_SIZE_MB` in `.env` (überschreibt den Fallback `max_file_size_mb` in `backend/app/config.py`). Dies ist die maßgebliche, tatsächlich durchgesetzte Grenze (413 bei Überschreitung, geprüft während des Streamings, nicht erst am Ende).
2. **Nginx** — `client_max_body_size` in `deploy/nginx/fotoserver.conf` (aktuell `11264M`, ≈ Backend-Limit + 10 % Spielraum für Multipart-Overhead). Ist dieser Wert kleiner als das Backend-Limit, weist Nginx große Uploads bereits ab, bevor sie das Backend erreichen.

Das Frontend (`frontend/src/components/UploadForm.vue`, Konstante `MAX_BYTES`) filtert Dateien nur clientseitig vorab (bessere UX, keine Sicherheitsgrenze) und sollte aus Konsistenzgründen ebenfalls angepasst werden.

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
| Upload-Limit | 10 GB pro Datei (Streaming-Upload, konstanter RAM-Verbrauch) + fortlaufender Disk-Free-Space-Check |
| `secret_key` | Pflichtfeld, min. 32 Zeichen, kein Default — Validator wirft bei `CHANGE_ME` |
| Nginx-Headers | `X-Content-Type-Options`, `X-Frame-Options`, CSP, `Referrer-Policy` |
| hostapd.conf | `chmod 600 root:root` auf dem Pi; `ap_isolate=1` (Clients isoliert) |
| Authentifizierung | V1: WLAN-Passwort als einzige Zugangsschranke (kein Web-Login) |

---

## Dateistruktur auf dem Pi

```
/opt/fotoserver/
├── backend/
│   ├── app/
│   └── venv/               ← Python-venv (von install.sh angelegt)
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
└── .env                    ← Konfiguration (nicht in Git, chmod 600)
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
