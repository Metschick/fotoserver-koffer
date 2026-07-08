# Deployment auf Raspberry Pi 5

---

## Voraussetzungen

**Hardware:**
- Raspberry Pi 5 mit NVMe SSD (empfohlen) oder microSD
- WLAN-Adapter (Pi 5 onboard: `wlan0`)

**Betriebssystem:**
- Kali Linux ARM64 (oder Raspberry Pi OS mit apt-Paketquellen)

**Systempakete installieren:**
```bash
sudo apt update
sudo apt install -y \
    python3 python3-pip python3-venv \
    nginx hostapd dnsmasq iproute2 \
    ffmpeg libmagic1 sqlite3 \
    rsync
```

---

## Erstinstallation

```bash
# 1. Repository klonen (oder Release-Tarball)
git clone https://github.com/Metschick/fotoserver-koffer.git /opt/fotoserver
cd /opt/fotoserver

# 2. Konfiguration anlegen
cp .env.example .env
chmod 600 .env

# .env anpassen:
#   SECRET_KEY  → zufälligen Key eintragen:
#     python3 -c "import secrets; print(secrets.token_hex(32))"
#   HOTSPOT_PASSWORD → sicheres WLAN-Passwort setzen
#   HOTSPOT_SSID     → gewünschter Netzwerkname
#   HOTSPOT_COUNTRY  → Länderkürzel (z. B. DE)
nano .env

# 3. Vollständige Installation ausführen
sudo deploy/scripts/install.sh --source /opt/fotoserver --hotspot --desktop pi
```

Der `install.sh`-Lauf übernimmt:
- Python-venv anlegen, Pakete installieren
- Frontend-dist aus GitHub-Release laden
- systemd-Units installieren
- Nginx konfigurieren
- Hotspot-Konfiguration generieren
- Desktop-Shortcuts anlegen (mit `--desktop USERNAME`)

---

## Fotoserver starten und stoppen

```bash
# Fotoserver-Modus starten (Hotspot + alle Dienste)
sudo fotoserver-start.sh

# Status aller Dienste anzeigen
fotoserver-status.sh

# Fotoserver-Modus stoppen
sudo fotoserver-stop.sh

# Alle Dienste neu starten
sudo fotoserver-restart.sh
```

Nach dem Start erreichbar unter: **`http://192.168.4.1`**  
(oder unter beliebiger Domain — Captive-DNS leitet alle Anfragen auf den Pi um)

---

## Konfiguration (`.env`)

Die `.env`-Datei muss `chmod 600 root:root` gesetzt sein. systemd liest sie als root und übergibt die Werte als Umgebungsvariablen — der `fotoserver`-Prozess greift nie direkt auf die Datei zu. `install.sh` setzt diese Berechtigung bei jedem Lauf erneut (auch wenn `.env` schon existierte) — siehe auch „Datei-Ownership" unten.

Eine `.env`-Datei versorgt sowohl die `Settings`-Klasse des Backends als auch die
Shell-Skripte (`setup-hotspot.sh`, `fotoserver-backup.sh`) mit Werten — `HOTSPOT_*`,
`FOTOSERVER_BACKUP_*` und `FOTOSERVER_MODE` werden ausschließlich von den Skripten
gelesen. `Settings` ist deshalb mit `extra="ignore"` konfiguriert und überspringt
diese ihr unbekannten Schlüssel, statt beim Start abzubrechen (ohne dieses Flag
würde pydantic-settings mit `extra_forbidden` fehlschlagen, sobald systemd sie als
Umgebungsvariablen injiziert).

Wichtige Einstellungen:

| Variable | Beschreibung | Beispiel |
|---|---|---|
| `SECRET_KEY` | Zufälliger Key ≥ 32 Zeichen (Pflicht) | `openssl rand -hex 32` |
| `HOTSPOT_SSID` | WLAN-Netzwerkname | `FotoServer` |
| `HOTSPOT_PASSWORD` | WPA2-Passwort (8–63 Zeichen) | `MeinSicheresPasswort` |
| `HOTSPOT_COUNTRY` | ISO 3166-1 alpha-2 | `DE` |
| `HOTSPOT_IP` | Statische IP des Pi im Hotspot | `192.168.4.1` |
| `MAX_FILE_SIZE_MB` | Upload-Limit pro Datei (Streaming-Upload, RAM-Verbrauch unabhängig von der Dateigröße) | `10240` (10 GB) |
| `LOG_LEVEL` | Log-Level (`DEBUG`/`INFO`/`WARNING`/`ERROR`) | `INFO` |
| `FOTOSERVER_BACKUP_DIR` | Backup-Zielverzeichnis | `/media/usb-backup` |
| `FOTOSERVER_BACKUP_KEEP` | Anzahl behaltener Backups | `7` |

**Upload-Limit ändern:** `MAX_FILE_SIZE_MB` allein genügt nicht — `client_max_body_size` in `deploy/nginx/fotoserver.conf` muss konsistent mitgezogen werden (Nginx weist sonst große Uploads bereits vor dem Backend ab). Details und alle betroffenen Stellen: [docs/architecture.md](architecture.md#upload-limit-ändern).

Uploads im GB-Bereich über den WLAN-Hotspot können je nach Signalqualität mehrere Minuten dauern. `deploy/nginx/fotoserver.conf` setzt dafür `proxy_send_timeout`/`proxy_read_timeout`/`client_body_timeout` auf 3600 s und `proxy_request_buffering off`, damit Nginx den Request-Body direkt an FastAPI durchreicht statt ihn vollständig zwischenzupuffern.

---

## Backup

### Manuell

```bash
sudo fotoserver-backup.sh
```

Erstellt ein `fotoserver-backup-YYYY-MM-DDTHH-MM-SSZ.tar.gz` im Backup-Verzeichnis.

### Automatisch (täglicher systemd-Timer)

```bash
sudo systemctl enable --now fotoserver-backup.timer
systemctl list-timers fotoserver-backup.timer
```

### Backup auf USB-SSD

USB-SSD mounten und in der Backup-Service-Unit als Ziel setzen:

```bash
# /etc/systemd/system/fotoserver-backup.service.d/usb.conf
[Service]
Environment=FOTOSERVER_BACKUP_DIR=/media/usb-backup
```

```bash
sudo systemctl daemon-reload
sudo systemctl start fotoserver-backup.service
```

---

## Updates

```bash
sudo deploy/scripts/update.sh
```

Führt `git pull --ff-only` aus, aktualisiert pip-Pakete und startet den Fotoserver neu.

Nur für Git-basierte Installationen (nicht für `--version`-Installationen via Release).

---

## Logs

```bash
# Backend-Log (live)
sudo journalctl -u fotoserver-api -f

# Backup-Log (letzter Lauf)
sudo journalctl -u fotoserver-backup.service

# Alle Fotoserver-Dienste
sudo journalctl -t fotoserver --since '-1h'

# Nginx-Fehler
sudo journalctl -u nginx --since '-1h'
```

---

## Troubleshooting

**Hotspot startet nicht:**
```bash
sudo journalctl -u hostapd --since '-5m'
# Häufige Ursache: NetworkManager verwaltet wlan0 noch
sudo systemctl reload NetworkManager
sudo systemctl start fotoserver.target
```
(`fotoserver-start.sh` gibt `wlan0` seit dem Regressionsfix bereits selbst automatisch frei — dieser Schritt ist nur bei direktem `systemctl start fotoserver.target` ohne das Wrapper-Skript nötig.)

Zeigt `journalctl` `hostapd.service ... skipped, unmet condition check
ConditionFileNotEmpty=/etc/hostapd/hostapd.conf` (Status bleibt `inactive`, kein
`failed` — daher leicht zu übersehen): Das Debian-`hostapd`-Paket bringt weder eine
befüllte `/etc/hostapd/hostapd.conf` mit noch ist der Dienst standardmäßig
demaskiert. `setup-hotspot.sh` behebt beides automatisch (`systemctl unmask
hostapd` + Platzhalterdatei, damit die systemd-Condition erfüllt ist — die
tatsächlich genutzte Konfiguration bleibt `/etc/hostapd/fotoserver.conf` via
`DAEMON_CONF`). Tritt der Fehler dennoch auf, `setup-hotspot.sh` erneut laufen
lassen (idempotent):
```bash
sudo ./deploy/scripts/setup-hotspot.sh
sudo ./deploy/scripts/fotoserver-start.sh
```

**Backend antwortet nicht:**
```bash
sudo journalctl -u fotoserver-api --since '-5m'
# .env prüfen:
sudo cat /opt/fotoserver/.env | grep -v PASSWORD | grep -v KEY
```

**Nginx zeigt 502 Bad Gateway:**
```bash
# Backend läuft?
systemctl is-active fotoserver-api
# Backend-Port prüfen:
ss -tlnp | grep 8000
```

**Backup schlägt fehl:**
```bash
# Freier Speicherplatz prüfen
df -h /opt/fotoserver/backups
# Log des letzten Backup-Runs
sudo journalctl -u fotoserver-backup.service -n 50
```

---

## NetworkManager-Konflikt

`fotoserver-start.sh` stellt `/etc/NetworkManager/conf.d/99-fotoserver.conf` bei jedem Start automatisch wieder her, falls sie fehlt oder ein anderes Interface referenziert — ein manueller Eingriff ist im Normalfall nicht nötig.

Sollte NetworkManager `wlan0` dennoch während eines laufenden Fotoserver-Betriebs übernehmen (z. B. weil ein System-Update NetworkManager neu gestartet hat):

```bash
sudo systemctl reload NetworkManager
sudo systemctl restart fotoserver-wlan0.service
sudo systemctl restart hostapd
```

---

## Wechsel zwischen Hotspot- und Normalbetrieb

Der Wechsel läuft seit dem Regressionsfix vollautomatisch in `fotoserver-start.sh` bzw. `fotoserver-stop.sh` — für den normalen Betrieb (Desktop-Icons „Start"/„Stop" oder die gleichnamigen Skripte) ist **kein manueller Befehl** mehr nötig:

- **`fotoserver-start.sh`** gibt den in `.env` konfigurierten `HOTSPOT_INTERFACE` (Standard: `wlan0`) automatisch für den Hotspot frei, bevor die Dienste starten — legt `/etc/NetworkManager/conf.d/99-fotoserver.conf` idempotent an und lädt NetworkManager neu. Fehlt oder passt die Datei bereits, wird nichts unnötig neu geladen.
- **`fotoserver-stop.sh`** gibt das Interface nach dem Stoppen der Dienste automatisch wieder an NetworkManager zurück (entfernt dieselbe Datei + reload). Das läuft auch dann, wenn `fotoserver.target` bereits inaktiv war — der Stop ist vollständig idempotent, ein zweiter Klick auf „Stop" schadet nicht.
- Danach normal per GUI oder `nmcli device wifi connect "<SSID>" password "<...>"` mit einem WLAN verbinden.

Per Architekturentscheidung läuft der Pi standardmäßig im „Normalbetrieb" ohne Hotspot (siehe CLAUDE.md, Abschnitt „Start/Stop-Konzept") — genau diesen Zustand stellt `fotoserver-stop.sh` jetzt zuverlässig und ohne Zutun wieder her.

**Manueller Eingriff nur nötig, wenn:**
- `fotoserver.target` außerhalb der Skripte manipuliert wurde (z. B. direktes `systemctl stop fotoserver.target` statt `fotoserver-stop.sh`) — dann bleibt `99-fotoserver.conf` bestehen. Einfach `sudo ./deploy/scripts/fotoserver-stop.sh` nachträglich ausführen (idempotent, holt die NM-Freigabe nach, auch wenn nichts mehr zu stoppen ist).
- Sich `HOTSPOT_SSID`/`HOTSPOT_PASSWORD`/`HOTSPOT_INTERFACE` etc. in `.env` geändert haben — dafür weiterhin `sudo ./deploy/scripts/setup-hotspot.sh` erneut ausführen (regeneriert `hostapd.conf`/`dnsmasq.conf`; die NM-Freigabe selbst übernimmt beim nächsten Start ohnehin automatisch `fotoserver-start.sh`).

---

## Datei-Ownership: `/opt/fotoserver` als Git-Repo *und* Produktivinstallation

Dieses Projekt geht bewusst davon aus, dass `/opt/fotoserver` gleichzeitig das Git-Arbeitsverzeichnis (Entwicklung, Commits, `git push`) und die laufende Installation ist. `install.sh` chownt deshalb **nicht** rekursiv den gesamten Baum auf `root`, sondern nur gezielt die sicherheitsrelevanten Pfade:

| Pfad | Owner | Grund |
|---|---|---|
| `.env` | `root:root`, `600` | Enthält Secrets (`SECRET_KEY`, Passwort-Hashes, WLAN-Passwort) |
| `deploy/scripts/*.sh` | `root:root`, `755` | Werden per `sudo`/`pkexec` root-privilegiert aufgerufen; `fotoserver-start.sh` & Co. prüfen diese Ownership explizit (Schritt 11/12) — verhindert, dass ein unprivilegierter Nutzer die Steuerskripte austauscht. Zum Bearbeiten: `sudo`. |
| `uploads/`, `data/` | `fotoserver:fotoserver`, `755` | Laufzeitdaten, die der Service selbst beschreibt (via `setup-systemd.sh`) |
| Alles andere (Code, `backend/venv`, `deploy/nginx`, `deploy/systemd`, `deploy/hotspot`, `deploy/desktop`, `docs/`, `.git/`) | Betreiber-User (z. B. `kali`) | Git-verwalteter/generierter Baum — wird direkt bearbeitet und gepusht |

Schutz vor einem kompromittierten `fotoserver`-Serviceprozess liefert `ProtectSystem=strict` + `ReadWritePaths=uploads,data` in `fotoserver-api.service` (Schritt 10) — der Service kann unabhängig von Unix-Ownership nirgends außer `uploads/`+`data/` schreiben. Root-Ownership des Codes wäre daher redundante Härtung, die nur die eigene Entwicklung behindert.

**Wichtig:** `sudo chown -R <user>:<user> /opt/fotoserver` (z. B. um sich selbst Schreibzugriff zu verschaffen) setzt auch `.env` und `uploads/`/`data/` auf den eigenen User zurück und hebt damit deren Absicherung auf. Danach `sudo ./deploy/scripts/setup-systemd.sh` (stellt `uploads/`/`data/`-Ownership wieder her) und `sudo chown root:root .env && sudo chmod 600 .env` erneut ausführen.
