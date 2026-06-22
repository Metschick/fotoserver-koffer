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

### Nächster Schritt

**Schritt 3 – Upload-System** (noch nicht begonnen)

Geplanter Inhalt:
* `POST /api/upload`: Datei-Upload (multipart/form-data)
* `backend/app/services/storage.py`: Dateispeicherung mit UUID4-Dateinamen, Ordnerstruktur `Gerätename/YYYY-MM-DD/`
* `backend/app/utils/file_utils.py`: MIME-Prüfung via python-magic (Magic Bytes), Dateinamen-Sanitierung, Disk-Space-Check
* Authentifizierung: Nutzer-Passwort-Middleware (bcrypt-Vergleich, HTTP-Only Cookie)
* Tests: Upload-Erfolg, zu große Datei, ungültiger MIME-Typ, volle Festplatte

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

---

## Offene Entscheidungen

Diese Punkte wurden im Architekturplan bewusst zurückgestellt und müssen vor dem jeweiligen Implementierungsschritt geklärt werden.

### Vor Schritt 3 (Upload-System) — ✅ geklärt

* **Auth-Scope:** Kein Web-Login für normale Nutzer. Das WLAN-Passwort des Hotspots ist die primäre Authentifizierung. Upload und Galerie sind für alle Geräte im Hotspot-Netz offen. Admin-Login (für Löschen, Serververwaltung) wird erst später in einem separaten System umgesetzt.
* **Session-Dauer:** Entfällt für normale Nutzer (kein Web-Login). Admin-Sessions werden separat konzipiert, wenn das Admin-Interface implementiert wird.
* **Upload-Verhalten bei Duplikaten:** Immer speichern — jeder Upload erhält eine neue UUID, keine Duplikaterkennung in Version 1.

### Vor Schritt 6 (Frontend)

* **Sprache der Benutzeroberfläche:** Deutsch oder Englisch?
* **Dark/Light Mode:** Soll das Frontend einen Dark Mode unterstützen?

### Vor Schritt 11 (Start/Stop-Skripte)

* **Sudo-Strategie:** Soll der Operator-User sudo-Rechte für `systemctl start/stop fotoserver.target` ohne Passwort haben, oder soll PolicyKit für die Desktop-Shortcuts genutzt werden?

### Langfristig offen (Version 2)

* **Backup-Ziel:** Lokales Backup auf externer USB-SSD, oder Backup über Netzwerk auf einen anderen Rechner?
* **Mehrsprachigkeit:** Deutsch/Englisch-Umschaltung im Interface?
* **Maximale Upload-Größe für Videos:** 100 MB aktuell — realistisch für längere Videos? Eventuell auf 500 MB erhöhen?
