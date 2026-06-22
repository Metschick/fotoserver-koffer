# Architekturplan: Fotoserver-Koffer

**Erstellt:** 2026-06-22  
**Status:** Bestätigt – wartet auf Implementierungsstart  
**Ziel:** Modularer, offline-fähiger Fotoserver auf Raspberry Pi 5 / Kali Linux

---

## 1. Technologie-Entscheidungen

### Backend
| Komponente | Wahl | Begründung |
|---|---|---|
| Framework | **FastAPI** (Python 3.11+) | Async, leichtgewichtig, OpenAPI automatisch, gut auf ARM |
| Datenbank | **SQLite** (WAL-Modus) | Kein separater DB-Prozess, perfekt für Embedded; WAL für concurrent reads |
| ORM | **SQLModel** | FastAPI-native, Pydantic-kompatibel, SQLite-geeignet |
| Thumbnails | **Pillow** (Bilder) + **ffmpeg** (Videos) | Pillow für Bilder; ffmpeg für Video-Frames (ARM64-verfügbar via apt) |
| MIME-Prüfung | **python-magic** | Magic-Byte-Prüfung, kein Client-Header vertrauen |
| ASGI-Server | **Uvicorn** | Standardwahl für FastAPI, systemd-integrierbar |

### Frontend
| Komponente | Wahl | Begründung |
|---|---|---|
| Framework | **Vue 3 + Vite** | Leichtgewichtig, SPA-fähig, einfacher Build |
| CSS | **Tailwind CSS** | Utility-first, kein Design-System nötig, klein haltbar |
| Build | **Vite** | Schnell, einfache Konfiguration, statische Ausgabe |

> Alternative falls kein Node.js im Deploy-Ziel gewünscht: Reines HTML/JS/CSS ohne Build-Step. Entscheidung nach Frontend-Planung treffen.

### Infrastruktur
| Komponente | Wahl | Begründung |
|---|---|---|
| Reverse Proxy | **Nginx** | Standard, Kali-kompatibel, statische Files direkt bedienen |
| Prozess-Manager | **systemd** | Kali-nativ, Auto-Start, Logs via journald |
| WLAN-Hotspot | **hostapd + dnsmasq** | Standard auf Kali/Raspberry Pi, kein NetworkManager nötig |
| Paket-Manager | **pip + venv** | Keine Docker-Abhängigkeit, einfachstes Setup auf ARM |

---

## 2. Verzeichnisstruktur

```
fotoserver-koffer/
│
├── .github/
│   ├── workflows/
│   │   └── ci.yml                  ← Lint + Tests bei Push
│   └── ISSUE_TEMPLATE/
│       └── bug_report.md
│
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                 ← FastAPI App-Instanz, Lifespan
│   │   ├── config.py               ← Settings via pydantic-settings / .env
│   │   ├── database.py             ← SQLite-Engine + Session
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   └── media.py            ← SQLModel: Media, Album
│   │   ├── routers/
│   │   │   ├── __init__.py
│   │   │   ├── upload.py           ← POST /api/upload
│   │   │   ├── gallery.py          ← GET  /api/gallery, /api/media/{id}
│   │   │   └── health.py           ← GET  /api/health
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── storage.py          ← Dateispeicherung, Ordnerstruktur
│   │   │   └── thumbnail.py        ← Thumbnail-Erzeugung via Pillow
│   │   └── utils/
│   │       ├── __init__.py
│   │       └── file_utils.py       ← MIME-Typen, Dateinamen-Sanitierung
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── conftest.py
│   │   ├── test_upload.py
│   │   └── test_gallery.py
│   ├── requirements.txt
│   └── pyproject.toml
│
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   │   ├── UploadForm.vue
│   │   │   ├── GalleryGrid.vue
│   │   │   ├── MediaViewer.vue
│   │   │   └── NavBar.vue
│   │   ├── views/
│   │   │   ├── HomeView.vue
│   │   │   ├── UploadView.vue
│   │   │   └── GalleryView.vue
│   │   ├── api/
│   │   │   └── client.js           ← Axios-Wrapper für Backend-API
│   │   ├── App.vue
│   │   └── main.js
│   ├── public/
│   │   └── favicon.ico
│   ├── index.html
│   ├── vite.config.js
│   ├── tailwind.config.js
│   └── package.json
│
├── deploy/
│   ├── nginx/
│   │   └── fotoserver.conf         ← Nginx-Konfiguration (Template)
│   ├── systemd/
│   │   ├── fotoserver.target       ← Gruppt alle Services; NICHT autostart
│   │   └── fotoserver-api.service  ← FastAPI/Uvicorn-Prozess
│   ├── hotspot/
│   │   ├── hostapd.conf.template   ← WLAN-Hotspot-Konfiguration
│   │   └── dnsmasq.conf.template   ← DHCP + DNS für Hotspot
│   └── scripts/
│       ├── install.sh              ← Einmaliges Setup
│       ├── fotoserver-start.sh     ← Fotoserver-Modus starten
│       ├── fotoserver-stop.sh      ← Fotoserver-Modus stoppen
│       ├── fotoserver-status.sh    ← Status aller Komponenten
│       ├── fotoserver-restart.sh   ← Neustart nach Update
│       ├── setup-hotspot.sh        ← Einmalige Hotspot-Konfiguration
│       ├── setup-nginx.sh          ← Einmalige Nginx-Konfiguration
│       └── update.sh               ← Git pull + fotoserver-restart
│
├── docs/
│   ├── architecture.md             ← Dieses Dokument (finale Version)
│   ├── deployment.md               ← Schritt-für-Schritt Raspberry Pi Setup
│   ├── development.md              ← Lokale Entwicklung unter WSL
│   ├── api.md                      ← API-Referenz
│   └── hotspot.md                  ← Hotspot-Einrichtung
│
├── uploads/                        ← gitignored! Nutzerdaten
│   └── .gitkeep
├── data/                           ← gitignored! SQLite DB
│   └── .gitkeep
│
├── .env.example                    ← Vorlage für lokale .env
├── .gitignore
├── CLAUDE.md
├── LICENSE
└── README.md
```

---

## 3. Backend-Architektur

### API-Endpunkte (Planung)

```
POST   /api/upload              ← Datei hochladen (multipart/form-data)
GET    /api/gallery             ← Alle Medien (paginiert, sortierbar)
GET    /api/gallery/{album}     ← Medien eines Albums
GET    /api/media/{id}          ← Einzelnes Medium (Metadaten)
GET    /api/media/{id}/thumb    ← Thumbnail
DELETE /api/media/{id}          ← Medium löschen (optional)
GET    /api/health              ← Healthcheck
```

### Datenbankschema (Planung)

```
Media
─────────────────────────────────
id          INTEGER  PK
filename    TEXT     (nur Metadatum, NIE in Pfad)
stored_as   TEXT     (UUID + Originalerweiterung, Basis für Dateipfad)
mime_type   TEXT     (server-seitig per magic bytes geprüft)
size_bytes  INTEGER
album       TEXT     (nur [a-zA-Z0-9_-] erlaubt, Whitelist-validiert)
uploaded_at DATETIME
thumb_path  TEXT     (nullable)
```

**Sicherheits-Invarianten (Review-Finding #1/#2/#3):**
- `stored_as` = UUID4 + sanitierte Originalerweiterung (z.B. `a1b2c3-d4e5.jpg`)
- `filename` (Original) wird NUR in der Datenbank gespeichert, nie als Dateipfad verwendet
- MIME-Typ wird server-seitig per `python-magic` (Magic Bytes) geprüft, nicht per HTTP-Header
- Album-Name: Regex `^[a-zA-Z0-9_-]{1,50}$` vor Dateisystem-Verwendung
- SQLite: `journal_mode=WAL` + `busy_timeout=5000` für concurrent access

### Speicher-Konzept

```
uploads/
└── 2026-06-22/           ← Album = Upload-Datum
    ├── abc123.jpg
    ├── def456.mp4
    └── thumbnails/
        └── abc123_thumb.jpg
```

---

## 4. Frontend-Architektur

### Views (Seiten)

| View | Funktion |
|---|---|
| `HomeView` | Startseite mit Status + Quick-Links |
| `UploadView` | Drag & Drop Upload mit Fortschrittsanzeige |
| `GalleryView` | Raster-Galerie mit Filterfunktion |

### Key-Features

- Drag & Drop Upload mit Fortschrittsbalken
- Vorschau vor dem Upload
- Responsive Grid-Galerie
- Vollbild-Viewer für Bilder
- Video-Player für Videos
- Funktioniert ohne Internet (alle Assets lokal)

---

## 5. Konfigurationsdateien

### `.env.example`
```
# Backend
UPLOAD_DIR=./uploads
DATA_DIR=./data
MAX_FILE_SIZE_MB=100
DISK_MIN_FREE_GB=2
ALLOWED_TYPES=image/jpeg,image/png,image/gif,image/webp,video/mp4,video/quicktime
SECRET_KEY=CHANGE_ME_USE_openssl_rand_hex_32

# Server
HOST=0.0.0.0
PORT=8000

# Hotspot (nur Pi) — Echte Werte NUR in .env, nie committen
HOTSPOT_SSID=FotoServer
HOTSPOT_PASSWORD=CHANGE_ME
```

**Hinweis:** `hostapd.conf` auf dem Pi muss `chmod 600` + `chown root:root` gesetzt werden.

### `backend/pyproject.toml`
- Projektmetadaten
- Abhängigkeiten (fastapi, sqlmodel, pillow, uvicorn, pydantic-settings)
- Dev-Abhängigkeiten (pytest, httpx, ruff)

### `frontend/vite.config.js`
- API-Proxy auf Backend (Entwicklung)
- Build-Output nach `frontend/dist/`
- Nginx bedient `dist/` als statische Dateien

---

## 6. GitHub-Struktur

### Branches
```
main          ← stabil, deployed auf Pi
dev           ← aktuelle Entwicklung
feature/*     ← neue Features
fix/*         ← Bugfixes
```

### CI-Pipeline (`.github/workflows/ci.yml`)
```
on: push, pull_request

jobs:
  backend:
    - Python 3.11 setup
    - pip install -r requirements.txt
    - ruff check (Linting)
    - pytest tests/

  frontend:
    - Node.js setup
    - npm install
    - npm run build (Compile-Check)
```

### `.gitignore` (kritische Einträge)
```
.env
uploads/
data/
*.db
*.sqlite
__pycache__/
*.pyc
.venv/
venv/
node_modules/
dist/
*.log
*.key
*.pem
```

---

## 7. Deployment-Strategie (Raspberry Pi 5 / Kali Linux)

### Einmaliges Setup (via `install.sh`)

```
1. System-Pakete:    apt install python3 python3-venv nginx hostapd dnsmasq
2. Repo klonen:      git clone <repo> /opt/fotoserver
3. Python venv:      python3 -m venv /opt/fotoserver/.venv
4. Dependencies:     pip install -r requirements.txt
5. Frontend bauen:   npm ci && npm run build  (einmalig auf PC/Pi)
6. .env konfigurieren (aus .env.example)
7. systemd aktivieren
8. Nginx konfigurieren
9. (Optional) Hotspot aktivieren
```

### Aktualisierung (via `update.sh`)
```
git pull origin main
pip install -r requirements.txt
./deploy/scripts/fotoserver-restart.sh
```

---

## 8. Hotspot-Integration (späterer Schritt)

### Konzept
- `hostapd`: Erstellt WLAN-Access-Point auf dem Pi
- `dnsmasq`: DHCP-Server + DNS → alle Domains → Pi-IP
- Geräte verbinden sich mit dem WLAN `FotoServer`
- Browser → `http://foto.local` oder `http://192.168.4.1` → Fotoserver

**Wichtig (Review-Finding):** Kali nutzt standardmäßig NetworkManager. Für `wlan0` muss NetworkManager deaktiviert werden:
```
# /etc/NetworkManager/conf.d/99-unmanage-wlan0.conf
[keyfile]
unmanaged-devices=interface-name:wlan0
```

### Konfiguration (Template, Secrets via .env)
```
# hostapd.conf.template
interface=wlan0
ssid=${HOTSPOT_SSID}
wpa_passphrase=${HOTSPOT_PASSWORD}
hw_mode=g
channel=6
```

### Systemd-Abhängigkeiten
```
fotoserver-api.service
  After=network.target hostapd.service dnsmasq.service
  PartOf=fotoserver.target
```
Alle Fotoserver-Services sind `PartOf=fotoserver.target`. Das Target selbst hat `DefaultDependencies=no` und ist **nicht** in `multi-user.target` eingehängt → kein Autostart beim Booten.

---

## 9. Nginx-Integration (späterer Schritt)

```nginx
server {
    listen 80;
    server_name _;

    # Statisches Frontend
    root /opt/fotoserver/frontend/dist;
    index index.html;
    try_files $uri $uri/ /index.html;

    # API-Proxy zum FastAPI-Backend
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        client_max_body_size 500M;
    }

    # Upload-Dateien direkt ausliefern — Sicherheits-Header Pflicht (Review #3)
    location /uploads/ {
        alias /opt/fotoserver/uploads/;
        add_header X-Content-Type-Options nosniff;
        add_header Content-Disposition "attachment";
        add_header X-Frame-Options DENY;
    }
}
```

---

---

## 10. Start/Stop-Konzept (Betriebsmodi)

### Grundprinzip

Der Fotoserver läuft **nicht permanent**. Der Pi bootet in den Normalbetrieb (ohne Fotoserver-Funktion). Der Fotoserver-Modus wird bewusst gestartet und gestoppt.

```
Normalbetrieb:   Pi läuft, kein Hotspot, kein Webserver aktiv
                      ↓  fotoserver-start.sh
Fotoserver-Modus:  Hotspot + dnsmasq + nginx + FastAPI aktiv
                      ↓  fotoserver-stop.sh
Normalbetrieb:   Alle Fotoserver-Dienste gestoppt
```

### Technische Umsetzung: systemd Target

Ein `fotoserver.target` gruppiert alle zugehörigen Services. Das Target wird **nicht** aktiviert (`systemctl enable` wird nicht ausgeführt) → kein Start beim Booten.

```
fotoserver.target
├── Wants: hostapd.service
├── Wants: dnsmasq.service
├── Wants: nginx.service
└── Wants: fotoserver-api.service

fotoserver-api.service
  After:  network.target hostapd.service dnsmasq.service
  PartOf: fotoserver.target
```

Start-Reihenfolge (systemd löst Abhängigkeiten automatisch auf):
1. `hostapd` (WLAN-Hotspot)
2. `dnsmasq` (DHCP + DNS)
3. `fotoserver-api` (FastAPI Backend)
4. `nginx` (Reverse Proxy)

Stop-Reihenfolge (umgekehrt, automatisch durch systemd):
1. `nginx`
2. `fotoserver-api`
3. `dnsmasq`
4. `hostapd`

### Convenience-Skripte

```bash
# Fotoserver-Modus starten
sudo systemctl start fotoserver.target
# → fotoserver-start.sh

# Fotoserver-Modus stoppen
sudo systemctl stop fotoserver.target
# → fotoserver-stop.sh

# Status aller Komponenten
systemctl status fotoserver.target fotoserver-api.service hostapd.service dnsmasq.service nginx.service
# → fotoserver-status.sh

# Neustart (z.B. nach Code-Update)
sudo systemctl restart fotoserver.target
# → fotoserver-restart.sh
```

Die Skripte unter `deploy/scripts/` sind dünne Wrapper um `systemctl`-Aufrufe — für einfache Bedienung ohne systemd-Kenntnisse.

### Spätere Erweiterung: Admin-Interface Toggle (Version 2)

Im Admin-Interface soll später ein Start/Stop-Button verfügbar sein:
- `POST /api/admin/server/stop` → `subprocess.run(['systemctl', 'stop', 'fotoserver.target'])`
- `GET /api/admin/server/status` → Abfrage via `systemctl is-active`
- Erfordert: Service-User mit `sudo`-Berechtigung für diese spezifischen `systemctl`-Befehle (sudoers-Eintrag)
- Sicherheit: nur über Admin-Passwort erreichbar

### .env-Ergänzung

```
# Betriebsmodus (wird von fotoserver-status.sh ausgelesen)
FOTOSERVER_MODE=manual   # 'manual' = nur per Skript starten
```


---

## 11. Bedienkonzept: Terminalfreie Steuerung

### Grundprinzip

Der Fotoserver soll langfristig ohne Terminal bedienbar sein. Die Architektur trennt dafür klar zwischen **Steuerungsebene** (wer bedient) und **Ausführungsebene** (was ausgeführt wird).

```
┌─────────────────────────────────────────────┐
│           Steuerungsebene (wechselt)         │
│  V1: Shell-Skripte                          │
│  V1.5: Desktop-Shortcuts (.desktop-Dateien) │
│  V2: System-Tray-App (Python/GTK)           │
│  V2: Web-Admin-Interface                    │
└────────────────┬────────────────────────────┘
                 │ spricht immer mit
                 ▼
┌─────────────────────────────────────────────┐
│        Ausführungsebene (unveränderlich)     │
│    systemd: fotoserver.target               │
│    (start / stop / restart / is-active)     │
└─────────────────────────────────────────────┘
```

**Invariante:** Kein GUI-Code berührt jemals direkt Prozesse, Dateien oder Netzwerkkonfiguration. Alle Steuerungsbefehle gehen ausschließlich über `systemctl` und die bestehenden Skripte.

---

### Version 1 — Shell-Skripte (jetzt)

```bash
./deploy/scripts/fotoserver-start.sh
./deploy/scripts/fotoserver-stop.sh
./deploy/scripts/fotoserver-status.sh
```

Ziel: Funktioniert. Terminal erforderlich.

---

### Version 1.5 — Desktop-Shortcuts (nächster einfacher Schritt)

`.desktop`-Dateien rufen die Shell-Skripte auf. Kali Linux (XFCE/GNOME) zeigt sie als klickbare Icons auf dem Desktop oder im Menü.

```
deploy/desktop/
├── fotoserver-start.desktop
├── fotoserver-stop.desktop
└── fotoserver-status.desktop
```

Beispiel `fotoserver-start.desktop`:
```ini
[Desktop Entry]
Type=Application
Name=Fotoserver starten
Icon=network-wireless
Exec=pkexec /opt/fotoserver/deploy/scripts/fotoserver-start.sh
Terminal=false
```

`pkexec` übernimmt die Rechteeskalation via PolicyKit — kein dauerhaftes `sudo`, kein offenes Root-Terminal.  
PolicyKit-Regel (`deploy/desktop/fotoserver.policy`) erlaubt nur diese spezifischen Skripte.

Ziel: Kein Terminal. Ein Doppelklick genügt.

---

### Version 2 — System-Tray-Applikation (späterer Schritt)

Eine kleine Python-GTK-Applikation läuft im System-Tray des Raspberry-Pi-Desktops:

```
deploy/tray-app/
├── fotoserver-tray.py       ← GTK-Tray-App
└── fotoserver-tray.service  ← systemd User-Service (autostart beim Desktop-Login)
```

Funktionen:
- Tray-Icon zeigt Betriebszustand (grün = aktiv, grau = gestoppt)
- Rechtsklick-Menü: Start / Stop / Neustart / Status / Beenden
- Status-Polling via `systemctl is-active fotoserver.target` (alle 5 Sekunden)
- Statusbericht als Desktop-Notification (via libnotify)

**Keine neue Backend-Logik nötig** — die Tray-App ist ein reines Frontend für die bestehenden `systemctl`-Befehle.

---

### Version 2 — Web-Admin-Interface (bereits geplant)

Bereits im Bedienkonzept vorgesehen (siehe Abschnitt 3, Admin-Endpunkte):
- `POST /api/admin/server/stop` → `systemctl stop fotoserver.target`
- `GET /api/admin/server/status` → `systemctl is-active`
- Erreichbar von jedem Gerät im Fotoserver-Hotspot
- Geschützt durch Admin-Passwort

---

### Verzeichnisstruktur-Ergänzung

```
deploy/
├── desktop/                 ← V1.5: .desktop-Dateien + PolicyKit-Regel
│   ├── fotoserver-start.desktop
│   ├── fotoserver-stop.desktop
│   ├── fotoserver-status.desktop
│   └── fotoserver.policy
└── tray-app/                ← V2: GTK-Tray-App
    ├── fotoserver-tray.py
    └── fotoserver-tray.service
```

---

### Versionspfad

| Version | Steuerung | Voraussetzung |
|---|---|---|
| **V1** | Shell-Skripte (Terminal) | Schritt 11 (systemd Target) |
| **V1.5** | Desktop-Shortcuts + PolicyKit | Nach V1, kein Backend-Umbau |
| **V2a** | System-Tray-App (GTK) | Nach V1.5, `python3-gi` auf Pi |
| **V2b** | Web-Admin-Interface | Backend Schritt 3 + Admin-Auth |


## 12. Implementierungsreihenfolge (Schritte)

| Schritt | Inhalt | Voraussetzung |
|---|---|---|
| **1** | Projektstruktur + .gitignore + .env.example + README | – |
| **2** | Backend-Grundgerüst (FastAPI, Config, DB, Health) | Schritt 1 |
| **3** | Upload-System (API + Storage-Service + Tests) | Schritt 2 |
| **4** | Thumbnail-Generierung (Pillow) | Schritt 3 |
| **5** | Galerie-API (Endpunkte + Tests) | Schritt 3 |
| **6** | Frontend-Grundgerüst (Vue 3 + Vite + Tailwind) | Schritt 1 |
| **7** | Upload-View + Drag & Drop | Schritt 6, 3 |
| **8** | Galerie-View + Viewer | Schritt 6, 5 |
| **9** | Nginx-Konfiguration | Schritt 5, 8 |
| **10** | systemd-Service | Schritt 9 |
| **11** | systemd Target + Start/Stop-Skripte | Schritt 10 |
| **12** | Desktop-Shortcuts + PolicyKit-Regel (V1.5) | Schritt 11 |
| **13** | install.sh (vollständiges Setup-Skript) | Schritt 12 |
| **14** | Hotspot-Setup-Skripte (inkl. NetworkManager-Entkopplung) | Schritt 13 |
| **15** | Logging-Konzept + Exception-Handler + Disk-Space-Check | Schritt 2 |
| **16** | Backup-Skript (SQLite + uploads/) | Schritt 13 |
| **17** | GTK-Tray-App (V2a, optional) | Schritt 11 |
| **18** | Dokumentation + Tests | – |

**Frontend-Build-Strategie (Review-Finding):** `dist/` wird im CI (GitHub Actions) gebaut und als Release-Artefakt bereitgestellt. Kein Node.js auf dem Pi nötig — `install.sh` lädt `dist/` als ZIP vom GitHub-Release.

Schritte 3–5 und 6–8 können parallel bearbeitet werden.

---

## Designentscheidungen (2026-06-22, bestätigt)

| Frage | Entscheidung |
|---|---|
| Frontend | Vue 3 + Vite + Tailwind CSS (Build im CI, kein Node.js auf Pi) |
| Authentifizierung | Einfaches gemeinsames Passwort (Upload + Galerie geschützt) |
| Album-Struktur | Automatisch: `Gerätename/YYYY-MM-DD/` (Gerätename per Upload-Formular) |
| Manuelle Alben | Nicht in Version 1, später optional erweiterbar |
| Lösch-Funktion | Ja, nur über separates Admin-Interface (eigenes Admin-Passwort) |

### Album-Struktur im Detail
```
uploads/
└── iPhone-von-Anna/
    └── 2026-06-22/
        ├── a1b2c3.jpg
        └── thumbnails/
            └── a1b2c3_thumb.jpg
└── Samsung-Galaxy/
    └── 2026-06-22/
        └── d4e5f6.mp4
```
Gerätename: Freitextfeld im Upload-Formular, Whitelist-Regex validiert.

### Passwort-Konzept
- **Nutzer-Passwort:** Ein gemeinsames Passwort für Upload + Galerie (in `.env`)
- **Admin-Passwort:** Separates Passwort für Delete-Funktion (in `.env`)
- Session via HTTP-Only Cookie (kein JWT, kein externer Auth-Dienst)
- Beide Passwörter als Hash (bcrypt) in `.env` — Klartext NIE committen

---

*Plan-Datei: `plans/architektur-fotoserver-koffer.md`*  
*Nächster Schritt: Schritt 1 – Projektstruktur erstellen (nach explizitem Start-Signal)*
