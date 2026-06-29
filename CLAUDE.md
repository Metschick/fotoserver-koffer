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

#### Schritt 8 – Galerie-View (Commit: f531e7d)

Erstellt am 2026-06-23. Enthält:

* `frontend/src/api/client.ts`: `API_BASE`-Konstante exportiert (bisher intern); `fetchJson` nimmt `RequestInit` inkl. optionalem `signal` entgegen
* `frontend/src/api/media.ts`: `fetchGallery(limit, offset, signal?)` via `fetchJson`; `fetchMediaBlob(id)` via `fetch()` + `URL.createObjectURL()` — lädt Originaldatei als Blob für Inline-Anzeige; `API_BASE`-Import ersetzt hartcodierten `/api`-Pfad
* `frontend/src/components/GalleryGrid.vue`: Responsives Thumbnail-Raster (`grid-cols-2 / 3 / 4`); 50 Items pro Batch; „Mehr laden"-Button; Lade-Skeleton (8 pulsierende Kacheln); Leer-Zustand mit CTA-Link `/upload`; Video-Play-Overlay; Hover-Info-Overlay (Gerätename + Datum); `AbortController` gegen Fetch nach Unmount; `emit('open', item, [...items.value])` sendet Snapshot (verhindert implizites Shared-State mit Viewer)
* `frontend/src/components/MediaViewer.vue`: `<Teleport to="body">` + `<Transition name="viewer-fade">`; Keyboard-Handler (`Escape`/`←`/`→`) via `document.addEventListener` — ausschließlich während Viewer offen (Lifecycle durch `v-if` in Parent sichergestellt); Body-Scroll-Lock via `onMounted`/`onUnmounted`; Blob-Loading mit Stale-ID-Guard (schnelles Navigieren überschreibt kein veraltetes Ergebnis); `aria-describedby="viewer-meta"`; kontextsensitive Pfeil-Labels (Bild vs. Video); Bilder: Blob-URL via `fetchMediaBlob`; Videos: Thumbnail-Vorschau + Download-Button (Inline-Wiedergabe in V1 nicht möglich, da `/file`-Endpunkt `Content-Disposition: attachment` setzt)
* `frontend/src/views/GalleryView.vue`: `<MediaViewer v-if="viewerItem !== null">` — Viewer nur gemountet wenn offen; eliminiert globalen Keyboard-Listener-Leak und Body-Overflow-Leak vollständig

**Build:** `vue-tsc && vite build` fehlerfrei (GalleryView-Chunk: 12.08 kB / gzip 4.16 kB).

**ECC-Review-Ergebnis:** 3 HIGH + 6 MEDIUM gefunden und behoben — Race Condition bei schneller Navigation (Stale-ID-Guard), globaler Keyboard-Listener immer aktiv (`v-if`-Fix), Body-Scroll-Lock-Leak (`v-if`-Fix), `aria-describedby` fehlend, kontextblinde Pfeil-Labels, Emit von Live-Array statt Snapshot, hardcodierter `/api`-Pfad, fehlender `AbortController`.

**Designentscheidung Video-Inline:** Videos können in V1 nicht inline abgespielt werden, da der `/api/media/{id}/file`-Endpunkt `Content-Disposition: attachment` setzt und Browser bei `<video src="...">` dann den Download triggern statt zu streamen. Lösung für V2: separater `/api/media/{id}/view`-Endpunkt ohne Content-Disposition.

#### Schritt 9 – Nginx-Konfiguration (Commit: 709296d)

Erstellt am 2026-06-23. Enthält:

* `deploy/nginx/fotoserver.conf`: Nginx-Server-Block — SPA-Fallback (`try_files`); Asset-Cache nur für `/assets/.*` (Vite-Hashes, `Cache-Control: public, immutable, 1y`); API-Proxy auf `127.0.0.1:8000` mit `client_max_body_size 110M` und 180s-Timeouts; gzip für Text/JSON/JS/CSS; Access- und Error-Log
* `deploy/scripts/setup-nginx.sh`: idempotentes Einrichtungsskript — Root-Check, nginx-Check, Pfad-Validierung (`^/[a-zA-Z0-9._/-]+$`), `sed`-Substitution des Template-Pfads, Backup der bestehenden Config, atomares Schreiben + `nginx -t`-Validierung vor Aktivierung, `ln -sf` in `sites-enabled`, Standard-Site deaktivieren
* `frontend/public/theme-init.js`: FOUC-Inline-Script aus `index.html` ausgelagert — ermöglicht `script-src 'self'` in CSP ohne `'unsafe-inline'`
* `frontend/index.html`: Inline-Script durch `<script src="/theme-init.js">` (synchron, kein defer — FOUC-Schutz bleibt erhalten) ersetzt

**Sicherheits-Header (alle Responses):** `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: same-origin`, `X-XSS-Protection: 0`, `Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob:; connect-src 'self'; font-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'`

**Nginx-`add_header`-Vererbung:** Locations mit eigenem `add_header` erben nicht den `server`-Block → alle Security-Header im `/assets/`-Location-Block explizit wiederholt.

**ECC-Security-Review-Ergebnis:** 2 HIGH + 3 MEDIUM gefunden und behoben — unvalidierter `$INSTALL_DIR` in `sed` (Injection-Schutz: Regex-Validierung), zu breite Asset-Regex (Einschränkung auf `^/assets/`), `Host: $host` durch `Host: 127.0.0.1` ersetzt, Config-Schreiben nach Backup + `nginx -t`-Validierung, CSP ergänzt.

#### Schritt 10 – systemd-Service (Commit: 806226b)

Erstellt am 2026-06-23. Enthält:

* `deploy/systemd/fotoserver-api.service`: FastAPI-Backend-Service — dedizierter Systemnutzer `fotoserver` (kein Login, kein Home); `WorkingDirectory=/opt/fotoserver`; `PYTHONPATH=/opt/fotoserver/backend` (damit `uvicorn app.main:app` das Paket findet); `EnvironmentFile=/opt/fotoserver/.env`; `Restart=on-failure`, `RestartSec=5s`, `TimeoutStopSec=30s`; `StartLimitIntervalSec=60s / StartLimitBurst=3` in `[Unit]`; `PartOf=fotoserver.target`
* `deploy/systemd/fotoserver.target`: Gruppen-Target für alle vier Services — `Wants=hostapd dnsmasq fotoserver-api nginx`; kein `[Install]`-Abschnitt (kein Autostart beim Booten); Startreihenfolge via `After=`
* `deploy/systemd/nginx.service.d/fotoserver.conf`: Drop-in — `PartOf=fotoserver.target`, `BindsTo=fotoserver.target`, `After=fotoserver-api.service`
* `deploy/systemd/hostapd.service.d/fotoserver.conf`: Drop-in — `PartOf=fotoserver.target`, `BindsTo=fotoserver.target` (kein `After=fotoserver.target` — würde zirkuläre Abhängigkeit erzeugen)
* `deploy/systemd/dnsmasq.service.d/fotoserver.conf`: Drop-in — `PartOf=fotoserver.target`, `BindsTo=fotoserver.target`, `After=hostapd.service`
* `deploy/scripts/setup-systemd.sh`: Systemnutzer anlegen, Verzeichnisse anlegen, Unit-Dateien atomisch installieren (`mktemp` + `mv`), Drop-ins atomisch installieren, `daemon-reload`; Validierung: Regex für INSTALL_DIR + Schutz gegen `/home`/`/root` (wegen `ProtectHome=yes`)

**Security-Hardening `fotoserver-api.service`:** `ProtectSystem=strict` + `ReadWritePaths=/opt/fotoserver/uploads /opt/fotoserver/data`; `PrivateDevices=yes`; `CapabilityBoundingSet=` (alle Capabilities entfernt); `SystemCallFilter=@system-service`; `ProtectKernelModules`, `ProtectKernelTunables`, `ProtectControlGroups`; `LockPersonality`, `RestrictNamespaces`, `RestrictRealtime`, `RestrictSUIDSGID`; `UMask=0027`

**Wichtig für Deployment:** `.env`-Datei muss nach dem Anlegen mit `chmod 600 / chown root:root` gesichert werden. systemd liest sie als root und übergibt Werte als Umgebungsvariablen — der `fotoserver`-Prozess selbst greift nie auf die Datei zu.

**Lifecycle-Verhalten:**
- `systemctl start fotoserver.target` → startet alle vier Services in Reihenfolge
- `systemctl stop fotoserver.target` → stoppt alle vier (via `PartOf=`)
- Wenn das Target in `failed` geht → auch nginx/hostapd/dnsmasq stoppen (via `BindsTo=`)
- `fotoserver.target` wird NICHT aktiviert (kein Autostart beim Booten)

**ECC-Security-Review-Ergebnis:** 2 HIGH + 3 MEDIUM gefunden und behoben — `ProtectSystem=full` → `strict` + `ReadWritePaths`, fehlende Hardening-Direktiven ergänzt, `.env`-Berechtigungshinweis in Setup-Script, nicht-atomares Schreiben → `mktemp`+`mv`, fehlende `BindsTo` in Drop-ins; 1 neues MEDIUM (INSTALL_DIR unter `/home` bricht `ProtectHome`) ebenfalls behoben.

#### Schritt 11 – Start/Stop-Skripte (Commit: 407d8a7)

Erstellt am 2026-06-24. Enthält:

* `deploy/scripts/fotoserver-start.sh`: Root-Check; `systemctl cat`-Prüfung (Target installiert?); Idempotenz-Check; `systemctl start fotoserver.target`; Polling-Loop (bis 10 s) bis Target `active`; ruft `fotoserver-status.sh` auf; Exit 1 wenn Target nicht aktiv wurde
* `deploy/scripts/fotoserver-stop.sh`: Root-Check; Idempotenz-Check (bereits inaktiv → Status anzeigen + Exit 0); `systemctl stop fotoserver.target`; ruft `fotoserver-status.sh` auf
* `deploy/scripts/fotoserver-status.sh`: Kein Root nötig; zeigt `is-active`-Status für hostapd, dnsmasq, fotoserver-api, nginx + fotoserver.target; Hinweis auf Logs / Start/Stop-Befehl
* `deploy/scripts/fotoserver-restart.sh`: Root-Check; Guard: Fehler wenn Target nicht aktiv (kein ungewolltes Aktivieren); Stop → Start → Polling-Loop; Exit 1 wenn Target nach Neustart nicht aktiv

**Sicherheits-Muster in allen Root-Skripten:** Vor dem Aufruf von `fotoserver-status.sh` wird via `stat -c '%U'` geprüft, dass das Skript `root` gehört — verhindert Privilege Escalation falls `deploy/scripts/` nicht korrekt gesichert ist.

**Sudo-Strategie V1:** Operator ruft Skripte manuell mit `sudo` auf — kein sudoers-Eintrag nötig. PolicyKit-Integration folgt in Schritt 12 (Desktop-Shortcuts).

**ECC-Security-Review-Ergebnis:** 4 MEDIUM + 3 LOW gefunden und behoben — Ownership-Check für Status-Skript (Privilege Escalation), `dirname` → `SCRIPT_DIR`-Muster in status.sh, Timeout-Loop ohne Fehlercode → Exit 1 nach Polling, totes `WAS_ACTIVE`-Flag + unbedingter Start in restart.sh → Guard, `$(seq)` → `{1..10}`, `grep`-basierter Unit-Check → `systemctl cat`, stop.sh zeigt jetzt Status auch wenn bereits inaktiv.

#### Schritt 12 – Desktop-Shortcuts (Commit: 7add867)

Erstellt am 2026-06-24. Enthält:

* `deploy/desktop/fotoserver-{start,stop,status,restart}.desktop`: Vier `.desktop`-Dateien für Kali XFCE/GNOME — `Terminal=true`; Start/Stop/Restart via `bash -c 'pkexec <script>; read -r dummy'`; Status ohne pkexec (kein Root nötig); Kategorien `System;Network;`
* `deploy/desktop/50-fotoserver.rules`: PolicyKit-JavaScript-Regel — Mitglieder der Gruppe `fotoserver-admin` dürfen start/stop/restart-Skripte via pkexec ohne Passwort ausführen; explizites `polkit.Result.NOT_HANDLED` für alle anderen Aktionen; Pfade enthalten `/opt/fotoserver`-Platzhalter (sed-Substitution durch setup-desktop.sh)
* `deploy/scripts/setup-desktop.sh`: Root-Check; `realpath -m`-Normalisierung + Abweichungs-Check gegen `..`-Traversal; Gruppe `fotoserver-admin` anlegen; optional: Benutzer zur Gruppe hinzufügen; PolicyKit-Regel atomisch installieren; **Skript-Verzeichnis und alle Steuerskripte auf `root:root 755` setzen** (sichert pkexec-Berechtigungsgrenze); Desktop-Dateien atomisch nach `/usr/share/applications/` installieren; optionaler Desktop-Symlink mit `USER_HOME`-Validierung; `update-desktop-database`

**Sicherheits-Kette:** Desktop-Klick → `bash -c 'pkexec <script>'` → polkit prüft: exakter Pfad UND Gruppe `fotoserver-admin` → `polkit.Result.YES` → Skript läuft als root via systemctl

**Ownership-Invariante:** `setup-desktop.sh` setzt nach der polkit-Regel-Installation `root:root 755` auf das gesamte `deploy/scripts/`-Verzeichnis und alle vier Steuerskripte. Damit ist sichergestellt, dass ein unprivilegierter Nutzer die durch polkit autorisierten Skripte nicht austauschen kann.

**ECC-Security-Review-Ergebnis:** 2 HIGH + 4 MEDIUM gefunden und behoben — fehlende Skript-Ownership-Sicherung in setup-desktop.sh (HIGH), `..`-Traversal in INSTALL_DIR-Regex via `realpath -m` + Abweichungs-Check (HIGH), fehlende Gruppe in `chown` für Desktop-Dateien (MEDIUM), `USER_HOME`-Validierung (MEDIUM), TMP_FILES-Array für vollständige trap-Abdeckung (MEDIUM), restart.sh startet jetzt auch wenn Fotoserver nicht aktiv war (MEDIUM-Usability); LOW: `read -r dummy`, explizites `NOT_HANDLED`.

**Offener Punkt für andere Setup-Skripte:** `setup-nginx.sh` und `setup-systemd.sh` verwenden dieselbe `INSTALL_DIR`-Regex ohne `realpath`-Normalisierung. Fix wurde in Schritt 13 nachgezogen.

#### Schritt 13 – Install-Skript (Commit: TBD)

Erstellt am 2026-06-24. Enthält:

* `deploy/scripts/install.sh`: Vollständige Erstinstallation — zwei Modi: `--source DIR` (lokaler Code via rsync) und `--version VER` (GitHub Release); `--desktop USER` für optionale Desktop-Shortcuts; `--no-apt` für Systeme mit vorinstallierten Paketen; 10-phasige Ausführung (apt, Verzeichnis, Code, venv, Frontend-dist, .env, Berechtigungen, systemd, nginx, Desktop)
* `deploy/scripts/update.sh`: Update via `git pull --ff-only` + pip install + setup-systemd + fotoserver-restart; nur für Git-basierte Installationen; prüft Remote-URL vor Pull
* `deploy/scripts/setup-nginx.sh`: Nachgezogen — `realpath -m`-Normalisierung + Abweichungs-Check + bedingtes `nginx reload` nach Re-Konfiguration
* `deploy/scripts/setup-systemd.sh`: Nachgezogen — `realpath -m`-Normalisierung + Abweichungs-Check

**Sicherheits-Muster in install.sh:**
- `FOTOSERVER_GITHUB_REPO`-Validierung: Regex `^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$` verhindert URL-Injection in `GITHUB_BASE`
- Quellcode-Download (--version): Download erst in Temp-Datei, dann `tar -xf` (kein Pipe-to-tar) — verhindert Partial-Extract bei Netzwerkfehler
- Einheitlicher akkumulierender Cleanup-Trap (`_CLEANUP_TMPS`-Array, kein `trap - EXIT`-Reset zwischen Phasen) — alle Temp-Dateien werden bei EXIT bereinigt
- curl: `--proto '=https' --tlsv1.2 --max-redirs 3` bei allen Netzwerk-Downloads
- `find`-basierte Berechtigungs-Setzung schließt `uploads/` und `data/` explizit aus (`-path ... -prune`) — verhindert world-readable Permissions auf Nutzerdaten bei Re-Runs
- `SECRET_KEY=CHANGE_ME`-Platzhalter-Check vor `sed`: Warnung wenn Platzhalter fehlt (kein stiller Fehler)

**ECC-Security-Review-Ergebnis:** 3 HIGH + 4 MEDIUM gefunden und behoben — `FOTOSERVER_GITHUB_REPO`-Injection (HIGH), Pipe-to-tar ohne Integrity-Check (HIGH), `trap - EXIT`-Reset lässt Temp-Dirs ungeschützt (HIGH); stille sed-Substitution bei fehlendem Platzhalter (MEDIUM), `find+chmod` auf `uploads/` bei Re-Runs (MEDIUM), `git pull` als root ohne Remote-URL-Validierung in update.sh (MEDIUM), kein `nginx reload` nach setup-nginx.sh bei laufendem Nginx (MEDIUM). LOW-Findings (curl-Protokoll-Flags, realpath-Verhalten): LOW-8 (--proto/--tlsv1.2) ebenfalls behoben.

#### Schritt 14 – Hotspot-Setup (Commit: TBD)

Erstellt am 2026-06-24. Enthält:

* `deploy/hotspot/hostapd.conf.template`: WPA2-only (CCMP/AES, kein TKIP); `ap_isolate=1` (Clients können sich nicht gegenseitig sehen); `ieee80211n=1` + `wmm_enabled=1` (802.11n auf Pi 5); Platzhalter `__INTERFACE__`, `__SSID__`, `__PASSWORD__`, `__COUNTRY__`
* `deploy/hotspot/dnsmasq.conf.template`: DHCP-Pool (`__DHCP_START__`–`__DHCP_END__`); `address=/#/__HOTSPOT_IP__` (Captive-DNS — alle Domains → Pi); `no-resolv` + `no-hosts` (kein Upstream-DNS); `bind-interfaces` (nur auf Hotspot-Interface)
* `deploy/hotspot/nm-unmanage.conf`: NetworkManager-Config-Snippet — verhindert NM-Übernahme des Hotspot-Interfaces; Platzhalter `__INTERFACE__`
* `deploy/hotspot/fotoserver-wlan0.service.template`: Oneshot-Service — setzt statische IP (`ip addr replace`) vor hostapd-Start; räumt IP beim Stop (`ip addr flush`) wieder ab; `PartOf=fotoserver.target`, `Before=hostapd.service`
* `deploy/scripts/setup-hotspot.sh`: Liest HOTSPOT_*-Werte aus .env (nie `source`); Python-Substitution für SSID/Passwort (Passwort via Umgebungsvariable, nicht Argument → nicht in `ps aux`); `install -m 600` für hostapd.conf; `install` statt `mv` für alle Config-Dateien (atomar auch über Filesystem-Grenzen); NM-`reload` statt `restart` (kein Verbindungsabbruch)
* `deploy/systemd/hostapd.service.d/fotoserver.conf`: Um `Wants=fotoserver-wlan0.service` + `After=fotoserver-wlan0.service` erweitert (Soft-Dep — hostapd startet auch ohne Hotspot-Setup)
* `.env.example`: `HOTSPOT_COUNTRY=DE` ergänzt; Hinweis zu `#` in Passwörtern
* `deploy/scripts/install.sh`: `--hotspot`-Flag ergänzt (ruft setup-hotspot.sh als optionale Phase 10 auf); `hostapd dnsmasq iproute2` zu APT-Paketen hinzugefügt; Desktop-Shortcuts zu Phase 11

**Sicherheits-Muster in setup-hotspot.sh:**
- `_env_get()`: grep + sed, nie `source .env`; verankerte Regex (`^KEY[[:space:]]*=`) verhindert Substring-Match auf ähnliche Keys
- HOTSPOT_PASSWORD via `FOTOSERVER_HOTSPOT_PW`-Umgebungsvariable an Python (nicht als argv — kein `ps aux`-Leak)
- IP-Validierung: Format-Regex + Oktet-Bereichsprüfung (0 und 255 als Host-Adressen ausgeschlossen)
- DHCP-Pool-Kollisions-Check: Pi-IP darf nicht im Pool .10–.100 liegen
- `install` (statt `mv`) für alle Config-Dateien: atomar auch wenn `/tmp` tmpfs ist
- NM-`reload` (SIGHUP) statt `restart`: re-reads conf.d ohne bestehende Verbindungen zu unterbrechen

**Captive-DNS-Konzept:** `address=/#/192.168.4.1` leitet alle DNS-Anfragen auf die Pi-IP um. Geräte im Hotspot erreichen den Fotoserver unter beliebiger Domain oder direkt über `192.168.4.1`. `no-resolv` verhindert Upstream-Lookups (kein Internet nötig).

**ECC-Security-Review-Ergebnis:** 0 HIGH + 4 MEDIUM + 3 LOW gefunden und behoben — IP-Oktet-Bereichsprüfung (MEDIUM), DHCP-Pool-Kollision mit Pi-IP (MEDIUM), `mv` von `/tmp` nach `/etc` nicht atomar auf Pi (MEDIUM, fix: `install`), NM-`restart` unterbricht Verbindungen (MEDIUM, fix: `reload`); `grep -v` Substring → verankerte Regex (LOW), `#` in Passwort truncates silently (LOW, Doku in .env.example).

#### Schritt 15 – Logging + Exception-Handler (Commit: TBD)

Erstellt am 2026-06-29. Enthält:

* `backend/app/logging_config.py`: `configure_logging(level)` — `logging.basicConfig()` mit journald-kompatiblem Format (`%(levelname)-8s %(name)s: %(message)s`); `sqlalchemy.engine` + `multipart.multipart` auf WARNING gedrosselt; in Tests ist `basicConfig()` No-op wenn pytest-Handler bereits gesetzt — `setLevel()`-Aufrufe laufen immer
* `backend/app/config.py`: `log_level: str = "INFO"` + `@field_validator` (case-insensitive, Whitelist: DEBUG/INFO/WARNING/ERROR/CRITICAL, normalisiert zu Uppercase); `_valid_log_levels: ClassVar[frozenset[str]]` — `ClassVar` schließt Feld von pydantic-settings-Parsing aus
* `backend/app/main.py`: Lifespan ruft `configure_logging(settings.log_level)` als erstes auf; `@app.exception_handler(RequestValidationError)` loggt auf WARNING mit Method+Path+errors(); `@app.exception_handler(Exception)` loggt auf ERROR via `logger.exception()` (schließt Traceback ein); gibt `{"detail": "Internal server error"}` zurück (kein Traceback nach außen); Startup/Shutdown via `logger.info`
* `backend/tests/test_exception_handler.py`: 9 Tests — 500-Status, leerer Body (kein Traceback/Klassen-Name), Logging-Inhalt (`r.getMessage()` statt `r.message`), Method+Path im Log, 422-Status, 422-Body-Format, ValidationError-Logging, HTTPException 404 nicht vom catch-all übernommen, 404-Body
* `.env.example`: `LOG_LEVEL=INFO` im Server-Abschnitt ergänzt

**Teststatus:** 56/56 grün, ruff clean.

**Starlette-Middleware-Verhalten:** `@app.exception_handler(Exception)` registriert sich auf `ServerErrorMiddleware`. In Starlette 1.3.1 sendet `ServerErrorMiddleware` die 500-Antwort und re-raisiert danach immer. TestClient mit `raise_server_exceptions=True` (Default) fängt diesen Re-raise — daher separates `crash_client`-Fixture mit `raise_server_exceptions=False` nötig. HTTPException wird von `ExceptionMiddleware` (darunter) abgefangen und erreicht den catch-all nicht.

**`r.getMessage()` vs `r.message`:** `LogRecord.message` enthält den rohen Format-String (z. B. `"Unbehandelter Fehler %s %s"`). Erst nach `Formatter.format()` wird `record.message = record.getMessage()` gesetzt. In Tests muss `r.getMessage()` verwendet werden, da pytest's `LogCaptureHandler.emit()` die Records nicht formatiert.

**ECC-Review-Ergebnis:** 0 HIGH + 3 MEDIUM gefunden und behoben — `r.message` statt `r.getMessage()` (MEDIUM, Test-Falsch-Positiv für Method/Path-Inhalt), fehlender OpenAPI-Schema-Cache-Reset in `error_route`-Teardown (MEDIUM), `configure_logging()` in Lifespan läuft nach Engine-Import (MEDIUM, architektonische Notiz — kein Korrektheitsproblem im Normalbetrieb, Library-Logger-Drosselung läuft via `setLevel()` unconditionally).

#### Schritt 16 – Backup-Skript (Commit: TBD)

Erstellt am 2026-06-29. Enthält:

* `deploy/scripts/fotoserver-backup.sh`: Root-Check; INSTALL_DIR + BACKUP_DIR-Validierung (`realpath -m`, Regex, kein `/home/`/`/root/`); BACKUP_KEEP-Validierung (Regex + Obergrenze 9999); SQLite-Backup via `sqlite3.Connection.backup()` (WAL-sicherer Online Backup API, `mode=ro`, `try/finally`); `cp -a` für uploads/ (kopiert Symlinks als Nodes, kein Dereferenzieren); `install -d -m 700` (atomar, kein Race-Window zwischen mkdir + chmod); tar.gz-Archiv in Temp-Datei im BACKUP_DIR (atomar über fs-Grenzen); Retention-Logik via `find -print0 | sort -rz | tail -zn | xargs -0` (NUL-getrennt, sicher bei Dateinamen mit Spaces); akkumulierender Cleanup-Trap
* `deploy/systemd/fotoserver-backup.service`: Oneshot-Service — direkter manueller Start via `systemctl start`; Hardening: `PrivateTmp=yes`, `ProtectSystem=strict`, `ReadWritePaths=/opt/fotoserver/backups /opt/fotoserver/uploads /opt/fotoserver/data`, `CapabilityBoundingSet=`, `NoNewPrivileges=yes`, `UMask=0077`; kommentierte `Environment=`-Zeilen für USB-SSD-Konfiguration
* `deploy/systemd/fotoserver-backup.timer`: Täglicher Timer um 02:00 Uhr; `Persistent=true` (verpasste Läufe nach Powerbank-Abschaltung nachholen); `RandomizedDelaySec=1800` (±30 min Streuung); optional via `systemctl enable --now fotoserver-backup.timer`
* `.env.example`: `FOTOSERVER_BACKUP_DIR` + `FOTOSERVER_BACKUP_KEEP` ergänzt

**Backup-Konzept V1:**
- Backup-Ziel: konfigurierbar via `FOTOSERVER_BACKUP_DIR` (Standard: `<INSTALL_DIR>/backups`)
- USB-SSD: `FOTOSERVER_BACKUP_DIR=/media/usb-backup` im systemd-Service als `Environment=` setzen
- Dateinamenformat: `fotoserver-backup-YYYY-MM-DDTHH-MM-SSZ.tar.gz`
- Archivinhalt: `fotoserver.db` (SQLite-Snapshot) + `uploads/` (alle Originaldateien + Thumbnails)
- Automatisierung: optional via `systemctl enable --now fotoserver-backup.timer`
- Manuell: `sudo fotoserver-backup.sh` oder `sudo systemctl start fotoserver-backup.service`

**ECC-Security-Review-Ergebnis:** 0 HIGH + 3 MEDIUM + 2 LOW gefunden und behoben — fehlende `/home/`/`/root/`-Sperre für BACKUP_DIR (MEDIUM), `mkdir -p + chmod` Race-Window → `install -d -m 700` (MEDIUM), BACKUP_KEEP-Overflow bei >2^63 → Obergrenze 9999 (MEDIUM); `find|xargs` Newline-Splitting → NUL-getrennte Pipeline (LOW), kein `try/finally` im Python-SQLite-Block (LOW).

#### Schritt 18 – Dokumentation + Tests (Commit: TBD)

Erstellt am 2026-06-29. Enthält:

* `docs/development.md`: Lokale Entwicklungsumgebung — Voraussetzungen, Backend-Setup (venv, uvicorn, pytest, ruff), Frontend-Setup (npm, Vite Dev-Server, Build), vollständige Projektstruktur-Übersicht, häufige Fehler
* `docs/architecture.md`: Systemübersicht (Blockdiagramm), Tech-Stack-Tabelle, Modul-Beschreibungen für alle `app/`-Komponenten, Sicherheitsentscheidungen-Tabelle, Dateistruktur auf dem Pi, systemd-Dienste-Tabelle, Frontend-Build-Strategie
* `docs/deployment.md`: Raspberry-Pi-Deployment-Guide — Systempakete, Erstinstallation via `install.sh`, Fotoserver starten/stoppen, `.env`-Konfigurations-Referenz, Backup (manuell + Timer + USB-SSD), Updates via `update.sh`, Logs-Befehle, Troubleshooting (Hotspot, Backend, Nginx, Backup)
* `backend/tests/test_config.py`: 8 Tests für Sicherheits-Validatoren — `secret_key` (CHANGE_ME abgelehnt, zu kurz abgelehnt, ≥32 Zeichen akzeptiert, länger akzeptiert), `log_level` (alle 5 Werte akzeptiert, Kleinschreibung normalisiert, ungültiger Wert abgelehnt, Leerstring abgelehnt)
* `backend/requirements-dev.txt`: `pytest-cov>=5.0.0` ergänzt
* `backend/pyproject.toml`: Coverage-Konfiguration (`--cov=app`, `term-missing`, `htmlcov/`); `[tool.coverage.run]` + `[tool.coverage.report]`

**Teststatus:** 68/68 grün, ruff clean.

**Coverage:** 91% gesamt — fehlende 9%: Video-Thumbnail-ffmpeg-Pfade (bereits via Mocks getestet), DB-Fehler-Pfade in `health.py`/`storage.py`, `check_disk_space`-Fehlerfall.

**Dokumentation:** `docs/development.md` und `docs/architecture.md` waren bereits in `README.md` verlinkt (seit Schritt 1), aber noch nicht erstellt. Alle drei Docs-Dateien füllen den `docs/`-Platzhalter aus.

### Nächster Schritt

**Schritt 17 – GTK-Tray-App (V2a, optional)** oder **V1 abgeschlossen — Deployment auf Pi**

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
