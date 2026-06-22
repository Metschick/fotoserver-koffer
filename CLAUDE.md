# Fotoserver-Koffer – Projektkontext

## Projektübersicht

Dieses Projekt ist der vollständige Neuaufbau des bisherigen Fotoservers.

Der alte Fotoserver lief auf einem separaten Acer-Laptop. Der neue Fotoserver soll künftig auf einem Raspberry Pi 5 mit Kali Linux betrieben und fest in den Raspberry-Pi-Hacking-Koffer integriert werden.

Ziel ist ein robuster, transportabler und langfristig wartbarer Fotoserver mit sauberer Projektstruktur, Versionsverwaltung und Dokumentation.

---

## Zielsystem

Hardware:

* Raspberry Pi 5
* NVMe SSD
* Integration in den Raspberry-Pi-Hacking-Koffer
* Betrieb über Powerbank möglich

Betriebssystem:

* Kali Linux (ARM64)

Entwicklungsumgebung:

* Haupt-PC mit WSL/Sub-Linux
* GitHub als zentrale Projektquelle
* Deployment später auf Raspberry Pi 5

---

## Hintergrund

Der bisherige Fotoserver wurde auf einem älteren Acer-Laptop betrieben.

Funktionen des bisherigen Systems:

* lokaler WLAN-Hotspot
* Upload von Bildern und Videos
* Speicherung der Dateien in Ordnerstrukturen
* spätere Galerieansicht
* Nutzung ohne Internetverbindung

Der bisherige Funktionsumfang dient als Orientierung, jedoch darf die Architektur bei Bedarf verbessert oder vollständig neu strukturiert werden.

---

## Projektziele

Der neue Fotoserver soll:

* sauber dokumentiert sein
* GitHub als zentrale Quelle verwenden
* reproduzierbar installierbar sein
* modular aufgebaut werden
* langfristig wartbar sein
* für andere Geräte leicht deploybar sein

---

## Nutzung von ECC

Für dieses Projekt soll bevorzugt das installierte ECC-Plugin verwendet werden.

Vorgehensweise:

1. Vor jeder größeren Änderung prüfen, ob ECC-Funktionen genutzt werden können.
2. ECC soll bevorzugt für Projektanalyse, Dateiverwaltung, Codeorganisation, Agent-Funktionen und verfügbare Entwicklungswerkzeuge verwendet werden.
3. Falls ECC eine Aufgabe unterstützen kann, soll ECC gegenüber manuellen Alternativen bevorzugt werden.
4. Nur wenn ECC die gewünschte Funktion nicht bereitstellt oder Fehler auftreten, sollen alternative Methoden genutzt werden.
5. Entscheidungen und Erkenntnisse aus der ECC-Nutzung sollen dokumentiert werden, sofern sie für das Projekt relevant sind.

---

## Dokumentationspflicht

Wichtige Entscheidungen sollen in dieser Datei festgehalten werden.

Dazu gehören insbesondere:

* Architekturentscheidungen
* Verzeichnisstruktur
* verwendete Frameworks
* Sicherheitsentscheidungen
* Deployment-Entscheidungen
* Raspberry-Pi-spezifische Anpassungen
* Änderungen an Upload- oder Galeriekonzepten

---

## GitHub-Regeln

Dieses Repository dient als zentrale Quelle des Projekts.

Nicht in Git speichern:

* Zugangsdaten
* Tokens
* API-Keys
* Passwörter
* private IP-Adressen
* hochgeladene Nutzerdaten
* Logdateien
* virtuelle Python-Umgebungen

Diese Dateien und Ordner sollen über `.gitignore` ausgeschlossen werden.

---

## Entwicklungsstrategie

Detaillierter Implementierungsplan: `plans/architektur-fotoserver-koffer.md` (Abschnitt 12)

Übergeordnete Phasen:

1. Grundstruktur und Projektgerüst
2. Backend-Grundgerüst
3. Upload-System
4. Thumbnail-Generierung
5. Galerie-API
6. Frontend-Grundgerüst
7. Upload-View
8. Galerie-View
9. Nginx-Konfiguration
10. systemd-Service
11. Start/Stop-Skripte
12. Desktop-Shortcuts (V1.5)
13. Install-Skript
14. Hotspot-Setup
15. Logging + Exception-Handler
16. Backup-Skript
17. GTK-Tray-App (V2a, optional)
18. Dokumentation + Tests

---

## Obsidian / Ray-Zentrale

Dieses Projekt wird zunächst unabhängig von der Ray-Zentrale entwickelt.

Während der Entwicklung sollen wichtige Entscheidungen in dieser Datei dokumentiert werden.

Später können relevante Informationen gesammelt und in die Obsidian-Struktur der Ray-Zentrale übertragen werden.

Diese Datei dient daher vorläufig als Projektgedächtnis.

---

## Arbeitsprinzip

Bei Unsicherheiten:

* zuerst diese Datei lesen
* bestehende Entscheidungen respektieren
* vorhandene Architektur prüfen
* Änderungen nachvollziehbar dokumentieren

Ziel ist ein sauber aufgebautes, langfristig wartbares Projekt mit vollständiger Nachvollziehbarkeit aller wichtigen Entscheidungen.

---

## Aktueller Projektstand (2026-06-22)

### Abgeschlossene Schritte

#### Schritt 1 – Projektstruktur (Commit: 5603ff3)

Erstellt am 2026-06-22. Enthält:

* Vollständiges Verzeichnis-Skelett: `backend/`, `frontend/`, `deploy/`, `docs/`, `plans/`
* `.gitignore`: schließt `.env`, `uploads/`, `data/`, `*.db`, `venv/`, `node_modules/`, Keys und Zertifikate aus
* `.env.example`: vollständige Konfigurationsvorlage mit Hinweisen zu bcrypt-Hashes und Key-Generierung
* `README.md`: Projektbeschreibung, Schnellstart-Anleitung, Start/Stop-Befehle
* `LICENSE`: MIT
* `backend/requirements.txt`: Produktionsabhängigkeiten (FastAPI, SQLModel, Pillow, python-magic, bcrypt, uvicorn)
* `backend/requirements-dev.txt`: Entwicklungsabhängigkeiten (pytest, httpx2, ruff)
* `backend/pyproject.toml`: Projektmetadaten, ruff-Konfiguration, pytest-Einstellungen
* Python-Package-Skeletons: leere `__init__.py`-Dateien in allen App-Modulen
* `.gitkeep`-Dateien in allen noch leeren Verzeichnissen

#### Schritt 2 – Backend-Grundgerüst (Commit: dcd8a1d)

Erstellt am 2026-06-22. Enthält:

* `backend/app/__init__.py`: `APP_VERSION = "0.1.0"` als zentrale Versionsquelle
* `backend/app/config.py`: pydantic-settings `Settings`-Klasse; `secret_key`-Validator (≥32 Zeichen, kein Default erlaubt); Properties für MIME-Typen, DB-Pfad und maximale Dateigröße
* `backend/app/database.py`: SQLite-Engine mit `journal_mode=WAL`, `busy_timeout=5000`, `foreign_keys=ON`; typisiertes `get_session()`-Generator
* `backend/app/models/media.py`: SQLModel `Media`-Tabelle mit `device_name`-Whitelist-Regex-Validator (`^[a-zA-Z0-9_-]{1,50}$`), timezone-awareem `uploaded_at` (`datetime.now(timezone.utc)`), `album_path`-Property
* `backend/app/routers/health.py`: `GET /api/health` mit DB-Konnektivitätsprüfung, `logger.exception` bei Fehler, Version aus `APP_VERSION`
* `backend/app/main.py`: FastAPI-Lifespan (Verzeichnisse + DB-Init), Router eingebunden
* `backend/conftest.py`: Root-Conftest setzt `SECRET_KEY` vor App-Import (verhindert Validator-Fehler in Tests)
* `backend/tests/conftest.py`: In-Memory-SQLite mit FK-Pragmas, `dependency_overrides` für saubere Session-Isolation
* `backend/tests/test_health.py`: 2 Tests (HTTP-Status + Body-Validierung)

**Teststatus:** 2/2 grün, ruff clean, keine Warnungen.

#### Schritt 3 – Upload-System (Commit: a6bfb95)

Erstellt am 2026-06-22. Enthält:

* `backend/app/utils/file_utils.py`: MIME-Prüfung via python-magic (Magic Bytes); `validate_device_name()` mit Whitelist-Regex; `safe_extension()` aus festem MIME→Erweiterung-Mapping; `check_disk_space()`
* `backend/app/services/storage.py`: `StorageService.save()` — atomarer Schreibvorgang via `tempfile.mkstemp()` + `os.replace()`; DB-Rollback mit Datei-Cleanup bei Commit-Fehler; Ordnerstruktur `upload_dir/Gerätename/YYYY-MM-DD/`
* `backend/app/routers/upload.py`: `POST /api/upload` — Streaming-Read (`max_bytes + 1`), MIME-Prüfung per Magic Bytes, Disk-Space-Check, 201-Response
* `backend/app/models/media.py`: `MediaRead`-Schema für API-Antworten
* `backend/tests/test_upload.py`: 15 Tests (Erfolg, zu groß, falscher MIME-Typ, leere Datei, ungültiger/fehlender Gerätename, Grenzwerte, volle Festplatte)
* `backend/tests/constants.py`: `TEST_SECRET_KEY` als zentrale Testkonstante

**Teststatus:** 15/15 grün, ruff clean.

**Auth-Entscheidung:** Kein Web-Login für normale Nutzer. WLAN-Passwort des Hotspots ist primäre Authentifizierung. Upload und Galerie für alle Geräte im Hotspot-Netz offen.

#### Schritt 4 – Thumbnail-Generierung (Commit: 4c90fcb)

Erstellt am 2026-06-22. Enthält:

* `backend/app/services/thumbnail.py`: `ThumbnailService` — Bilder via Pillow (EXIF-Transpose, RGB-Konvertierung, Resampling.LANCZOS, max 300×300); Videos via ffmpeg-Subprocess (erster Frame); graceful failure (Exceptions werden abgefangen, `None` zurückgegeben); Zombie-Prozess-Prevention bei `TimeoutExpired`
* Thumbnail-Pfad: `upload_dir/Gerätename/YYYY-MM-DD/thumbnails/UUID_thumb.jpg`; im DB-Feld `thumb_path` als relativer Pfad gespeichert
* Kein Orphan-Verzeichnis: `thumbnails/`-Dir wird erst angelegt wenn Pillow die Datei öffnen kann (Bilder) bzw. bei ffmpeg-Fehler wieder entfernt (Videos)
* `backend/app/models/media.py`: `MediaRead` um `thumb_path: Optional[str]` erweitert
* `backend/app/routers/upload.py`: Thumbnail-Generierung nach erfolgreichem Upload; Fehler blockieren Upload nicht
* `backend/tests/test_thumbnail.py`: 11 Tests (JPEG, PNG, Landscape-Ratio, kein Upscaling, korrupte Datei, kein Orphan-Dir, ungültiger MIME, ffmpeg nicht gefunden, ffmpeg-Fehler, kein Video-Orphan-Dir)
* `backend/tests/conftest.py`: `valid_jpeg`-Fixture (Pillow-erzeugtes Testbild)
* `backend/tests/test_upload.py`: Integrationstest `test_upload_valid_jpeg_sets_thumb_path`

**Teststatus:** 27/27 grün, ruff clean.

**Thumbnail-Entscheidung:** Synchrone Generierung (kein BackgroundTask in V1 — vereinfacht Fehlerbehandlung und ist auf Pi für lokale Uploads akzeptabel). `thumb_path` kann `null` sein wenn Generierung fehlschlägt (Upload trotzdem 201).

#### Schritt 5 – Galerie-API (Commit: 991121a)

Erstellt am 2026-06-22. Enthält:

* `backend/app/routers/gallery.py`: 5 Endpunkte — `GET /api/gallery` (paginiert, neueste zuerst); `GET /api/gallery/{device_name}/{date_str}` (Album nach Gerät+Datum, älteste zuerst + Sekundärsortierung nach id); `GET /api/media/{id}` (Metadaten); `GET /api/media/{id}/thumb` (Thumbnail als FileResponse); `GET /api/media/{id}/file` (Original als FileResponse mit `Content-Disposition: attachment`)
* `backend/app/models/media.py`: `GalleryPage`-Schema aus Router extrahiert; Kompositindex `(device_name, uploaded_at)` für Album-Abfragen
* Path-Traversal-Schutz: Alle DB-abgeleiteten Pfade werden per `.resolve()` + `is_relative_to()` gegen upload_dir geprüft
* `_assert_within_upload_dir()`: zentrale Sicherheitsfunktion für Dateipfad-Validierung
* `backend/tests/test_gallery.py`: 20 Tests (leer, Pagination, Sortierung, Album-Filter, Validierung, 404-Fälle, Datei fehlt auf Disk für thumb+original)

**Teststatus:** 47/47 grün, ruff clean.

**API-Designentscheidung:** Album-Pfad mit zwei getrennten URL-Segmenten `{device_name}/{date_str}` statt `{album:path}` — sauberer, kein Path-Parameter mit Slash.

#### Schritt 6 – Frontend-Grundgerüst (Commits: ff41569, 9916dd3)

Erstellt am 2026-06-22. Enthält:

* `frontend/package.json`: Vue 3 + Vue Router + Vite + Tailwind CSS + TypeScript (Node.js 20)
* `frontend/vite.config.ts`: `@/`-Alias auf `src/`; Dev-Proxy `/api` → `http://localhost:8000`
* `frontend/tailwind.config.js`: `darkMode: 'class'`, Content-Glob auf `.vue`+`.ts`
* `frontend/index.html`: Inline-Skript für sofortige FOUC-freie Theme-Initialisierung
* `frontend/src/composables/useTheme.ts`: Singleton-Ref für `'light'|'dark'`; liest System-Präferenz (`prefers-color-scheme`) beim ersten Besuch; persistiert in `localStorage('fotoserver-theme')`; togglet `dark`-Klasse auf `<html>`
* `frontend/src/components/NavBar.vue`: Logo + Navigationslinks (aktiver Link hervorgehoben) + Theme-Toggle-Button (Sonne/Mond-SVG)
* `frontend/src/router/index.ts`: `createWebHistory`; drei Routen (`/`, `/upload`, `/galerie`); Upload+Galerie als lazy-loaded Chunks
* `frontend/src/api/client.ts`: `fetchJson<T>()` + `ApiError`-Klasse (Basis für Steps 7+8)
* `frontend/src/views/`: `HomeView.vue` (Willkommensseite mit Links); `UploadView.vue` (Platzhalter für Schritt 7); `GalleryView.vue` (Platzhalter für Schritt 8)

**Dev-Start:** `cd frontend && npm install && npm run dev`
**Build:** `npm run build` → `dist/`

**UI-Entscheidungen:** Deutsch, Dark/Light Mode mit System-Präferenz + Toggle + LocalStorage (bestätigt vor diesem Schritt).

**Sicherheits-Nachbesserung (Commit: 9916dd3):** Vite 5 enthielt CVE GHSA-67mh-4wv8-2f99 (esbuild Dev-Server — unberechtigter Zugriff auf lokale Dateien). Upgrade auf Vite 8 + `@vitejs/plugin-vue` 6 + `vue-tsc` 3 → 0 bekannte Schwachstellen. Node.js wurde via nvm (ohne Root) auf Version 20.20.2 installiert.

#### Schritt 7 – Upload-View (Commit: f9d78b2)

Erstellt am 2026-06-22. Enthält:

* `frontend/src/api/media.ts`: `MediaRead`- und `GalleryPage`-Interfaces; `uploadFile()` via `XMLHttpRequest` (Fortschritts-Events); Rückgabe als `UploadHandle { promise, abort }` — ermöglicht saubere Abbruch-Behandlung beim Unmount
* `frontend/src/components/UploadForm.vue`: Composition API; Drag & Drop Zone mit `dragover`/`dragleave`/`drop`-Handlers; Gerätename-Feld mit Whitelist-Regex-Validierung (`^[a-zA-Z0-9_-]{1,50}$`) und `localStorage`-Persistenz; Datei-Vorschau via Object URLs (Bilder); per-Datei Fortschrittsbalken; Statusicons (Spinner/Häkchen/Fehler); abgelehnte Dateien (falscher MIME oder >100 MB) als Amber-Warnung; `onUnmounted`-Cleanup: laufenden XHR abbrechen + alle Object URLs revoken; Batch-Snapshot vor Upload-Loop verhindert Race Condition bei gleichzeitigem Hinzufügen
* `frontend/src/views/UploadView.vue`: Thin Wrapper um `<UploadForm />`

**Build:** `vue-tsc && vite build` fehlerfrei (10.44 kB / gzip 4.22 kB für UploadView-Chunk).

**ECC-Review-Ergebnis:** 2 HIGH + 5 MEDIUM gefunden und behoben — Object-URL-Leak auf Unmount, XHR nicht abgebrochen auf Unmount, doppelter Keyboard-Tab-Stop, fehlender `aria-label`, doppelter `:key` in `v-for`, Race Condition bei Live-Array-Iteration.

#### Schritt 8 – Galerie-View (Commit: ausstehend)

Erstellt am 2026-06-23. Enthält:

* `frontend/src/api/client.ts`: `API_BASE`-Konstante exportiert (bisher intern); `fetchJson` nimmt `RequestInit` inkl. optionalem `signal` entgegen
* `frontend/src/api/media.ts`: `fetchGallery(limit, offset, signal?)` via `fetchJson`; `fetchMediaBlob(id)` via `fetch()` + `URL.createObjectURL()` — lädt Originaldatei als Blob für Inline-Anzeige; `API_BASE`-Import ersetzt hartcodierten `/api`-Pfad
* `frontend/src/components/GalleryGrid.vue`: Responsives Thumbnail-Raster (`grid-cols-2 / 3 / 4`); 50 Items pro Batch; „Mehr laden"-Button; Lade-Skeleton (8 pulsierende Kacheln); Leer-Zustand mit CTA-Link `/upload`; Video-Play-Overlay; Hover-Info-Overlay (Gerätename + Datum); `AbortController` gegen Fetch nach Unmount; `emit('open', item, [...items.value])` sendet Snapshot (verhindert implizites Shared-State mit Viewer)
* `frontend/src/components/MediaViewer.vue`: `<Teleport to="body">` + `<Transition name="viewer-fade">`; Keyboard-Handler (`Escape`/`←`/`→`) via `document.addEventListener` — ausschließlich während Viewer offen (Lifecycle durch `v-if` in Parent sichergestellt); Body-Scroll-Lock via `onMounted`/`onUnmounted`; Blob-Loading mit Stale-ID-Guard (schnelles Navigieren überschreibt kein veraltetes Ergebnis); `aria-describedby="viewer-meta"`; kontextsensitive Pfeil-Labels (Bild vs. Video); Bilder: Blob-URL via `fetchMediaBlob`; Videos: Thumbnail-Vorschau + Download-Button (Inline-Wiedergabe in V1 nicht möglich, da `/file`-Endpunkt `Content-Disposition: attachment` setzt)
* `frontend/src/views/GalleryView.vue`: `<MediaViewer v-if="viewerItem !== null">` — Viewer nur gemountet wenn offen; eliminiert globalen Keyboard-Listener-Leak und Body-Overflow-Leak vollständig

**Build:** `vue-tsc && vite build` fehlerfrei (GalleryView-Chunk: 12.08 kB / gzip 4.16 kB).

**ECC-Review-Ergebnis:** 3 HIGH + 6 MEDIUM gefunden und behoben — Race Condition bei schneller Navigation (Stale-ID-Guard), globaler Keyboard-Listener immer aktiv (`v-if`-Fix), Body-Scroll-Lock-Leak (`v-if`-Fix), `aria-describedby` fehlend, kontextblinde Pfeil-Labels, Emit von Live-Array statt Snapshot, hardcodierter `/api`-Pfad, fehlender `AbortController`.

**Designentscheidung Video-Inline:** Videos können in V1 nicht inline abgespielt werden, da der `/api/media/{id}/file`-Endpunkt `Content-Disposition: attachment` setzt und Browser bei `<video src="...">` dann den Download triggern statt zu streamen. Lösung für V2: separater `/api/media/{id}/view`-Endpunkt ohne Content-Disposition.

### Nächster Schritt

**Schritt 9 – Nginx-Konfiguration** (Reverse Proxy, statische Files, Upload-Sicherheits-Header)

---

## Architekturentscheidungen (2026-06-22)

Vollständiger Plan: `plans/architektur-fotoserver-koffer.md`

### Tech-Stack (bestätigt)

| Schicht | Technologie | Begründung |
|---|---|---|
| Backend | FastAPI + Python 3.11 | ARM64-nativ, async, leichtgewichtig |
| Datenbank | SQLite (WAL-Modus) | Kein DB-Server, für concurrent reads geeignet |
| ORM | SQLModel | FastAPI-nativ, Pydantic-kompatibel |
| Thumbnails | Pillow (Bilder) + ffmpeg (Videos) | ffmpeg via apt auf Kali ARM64 |
| MIME-Prüfung | python-magic | Magic-Byte-Prüfung statt HTTP-Header |
| Frontend | Vue 3 + Vite + Tailwind CSS | SPA, statische Ausgabe für Nginx |
| Reverse Proxy | Nginx | Statische Files + API-Proxy |
| Prozess-Manager | systemd | Kali-nativ, Auto-Start |
| Hotspot | hostapd + dnsmasq | Standard auf Kali/Pi |
| Deployment | pip + venv (kein Docker) | Ressourcensparend für Pi/Powerbank |

### Sicherheitsentscheidungen (nach Review)

* Dateinamen im Dateisystem: ausschließlich UUID4 + sanitierte Erweiterung
* Original-Dateiname: nur als DB-Metadatum gespeichert, nie als Pfad
* MIME-Typ: server-seitig per Magic Bytes geprüft (python-magic), nie per HTTP-Header
* Album-Namen / Gerätename: Whitelist-Regex `^[a-zA-Z0-9_-]{1,50}$` vor Dateisystem-Verwendung (im Model als `field_validator` erzwungen)
* Nginx `/uploads/`: `X-Content-Type-Options: nosniff` + `Content-Disposition: attachment`
* Upload-Limit: 100 MB pro Datei + Disk-Free-Space-Check vor Schreiben
* `secret_key`: Pflichtfeld, min. 32 Zeichen, kein Default — Validator in `config.py`
* hostapd.conf auf Pi: `chmod 600 chown root:root`
* SQLite: `journal_mode=WAL` + `busy_timeout=5000` + `foreign_keys=ON`

### Start/Stop-Konzept (bestätigt)

Der Fotoserver darf nicht dauerhaft aktiv sein. Er wird bewusst gestartet und gestoppt.

* **Normalbetrieb:** Pi läuft ohne Hotspot und ohne Webserver
* **Fotoserver-Modus:** Hotspot + dnsmasq + nginx + FastAPI aktiv
* **Umschaltung:** via `fotoserver-start.sh` / `fotoserver-stop.sh` (Wrapper um systemd)
* **systemd Target:** `fotoserver.target` gruppiert alle Services — wird **nicht** aktiviert (kein Autostart beim Booten)
* **Start-Reihenfolge:** hostapd → dnsmasq → fotoserver-api → nginx (systemd löst Abhängigkeiten auf)
* **Admin-Toggle:** in Version 2 optional über Web-Interface (`POST /api/admin/server/stop`)
* **Skripte:** `deploy/scripts/fotoserver-{start,stop,status,restart}.sh`

### Bedienkonzept: Terminalfreie Steuerung (bestätigt)

Langfristig kein Terminal erforderlich. Architektur ist von Anfang an darauf vorbereitet.

**Invariante:** Alle Steuerungsbefehle gehen ausschließlich über `systemctl` → GUI-Code berührt niemals direkt Prozesse oder Netzwerkkonfiguration.

Versionspfad:
* **V1:** Shell-Skripte (Terminal) — Schritt 11
* **V1.5:** Desktop-Shortcuts via `.desktop`-Dateien + PolicyKit (`deploy/desktop/`) — kein Backend-Umbau
* **V2a:** GTK-System-Tray-App (`deploy/tray-app/fotoserver-tray.py`) — Status-Icon + Rechtsklick-Menü
* **V2b:** Web-Admin-Interface (bereits geplant: `POST /api/admin/server/stop`)

### Raspberry-Pi-spezifische Anpassungen

* NetworkManager muss `wlan0` freigeben (unmanaged-devices) bevor hostapd startet
* Frontend-Build läuft im CI (GitHub Actions), nicht auf dem Pi
* `install.sh` lädt `dist/` als Release-Artefakt — kein Node.js auf dem Pi nötig

### Frontend-Build-Strategie

* Entwicklung: Vite Dev-Server mit API-Proxy auf Backend
* Produktion: `npm run build` → `dist/` → GitHub Actions Release-Artefakt
* Deployment: `install.sh` lädt `dist/` vom GitHub-Release, kein Node.js auf Pi

### Designentscheidungen (2026-06-22, bestätigt)

* **Frontend:** Vue 3 + Vite + Tailwind CSS; Build im CI, kein Node.js auf dem Pi
* **Authentifizierung:** Einfaches gemeinsames Passwort (Upload + Galerie); separates Admin-Passwort für Lösch-Funktion; Session via HTTP-Only Cookie; Passwörter als bcrypt-Hash in `.env`
* **Album-Struktur:** Automatisch `Gerätename/YYYY-MM-DD/`; Gerätename per Freitextfeld im Upload-Formular (Whitelist-validiert); manuelle Alben erst ab Version 2
* **Lösch-Funktion:** Nur über Admin-Interface mit Admin-Passwort
* **UI-Sprache:** Deutsch (bestätigt vor Schritt 6)
* **Dark Mode:** Beide Modi (hell + dunkel); Standard: System-Präferenz (`prefers-color-scheme`); manueller Toggle in NavBar; Persistenz via `localStorage`; FOUC-Schutz via Inline-Skript in `index.html` (bestätigt vor Schritt 6)

---

## Offene Entscheidungen

Diese Punkte wurden im Architekturplan bewusst zurückgestellt und müssen vor dem jeweiligen Implementierungsschritt geklärt werden.

### Vor Schritt 3 (Upload-System) — ✅ geklärt

* **Auth-Scope:** Kein Web-Login für normale Nutzer. Das WLAN-Passwort des Hotspots ist die primäre Authentifizierung. Upload und Galerie sind für alle Geräte im Hotspot-Netz offen. Admin-Login (für Löschen, Serververwaltung) wird erst später in einem separaten System umgesetzt.
* **Session-Dauer:** Entfällt für normale Nutzer (kein Web-Login). Admin-Sessions werden separat konzipiert, wenn das Admin-Interface implementiert wird.
* **Upload-Verhalten bei Duplikaten:** Immer speichern — jeder Upload erhält eine neue UUID, keine Duplikaterkennung in Version 1.

### Vor Schritt 6 (Frontend) — ✅ geklärt

* **Sprache der Benutzeroberfläche:** Deutsch
* **Dark/Light Mode:** Beide Modi mit System-Präferenz als Standard + manueller Toggle + LocalStorage-Persistenz

### Vor Schritt 11 (Start/Stop-Skripte)

* **Sudo-Strategie:** Soll der Operator-User sudo-Rechte für `systemctl start/stop fotoserver.target` ohne Passwort haben, oder soll PolicyKit für die Desktop-Shortcuts genutzt werden?

### Langfristig offen (Version 2)

* **Backup-Ziel:** Lokales Backup auf externer USB-SSD, oder Backup über Netzwerk auf einen anderen Rechner?
* **Mehrsprachigkeit:** Deutsch/Englisch-Umschaltung im Interface?
* **Maximale Upload-Größe für Videos:** 100 MB aktuell — realistisch für längere Videos? Eventuell auf 500 MB erhöhen?
