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

Die `.env`-Datei muss `chmod 600 root:root` gesetzt sein. systemd liest sie als root und übergibt die Werte als Umgebungsvariablen — der `fotoserver`-Prozess greift nie direkt auf die Datei zu.

Wichtige Einstellungen:

| Variable | Beschreibung | Beispiel |
|---|---|---|
| `SECRET_KEY` | Zufälliger Key ≥ 32 Zeichen (Pflicht) | `openssl rand -hex 32` |
| `HOTSPOT_SSID` | WLAN-Netzwerkname | `FotoServer` |
| `HOTSPOT_PASSWORD` | WPA2-Passwort (8–63 Zeichen) | `MeinSicheresPasswort` |
| `HOTSPOT_COUNTRY` | ISO 3166-1 alpha-2 | `DE` |
| `HOTSPOT_IP` | Statische IP des Pi im Hotspot | `192.168.4.1` |
| `MAX_FILE_SIZE_MB` | Upload-Limit pro Datei | `100` |
| `LOG_LEVEL` | Log-Level (`DEBUG`/`INFO`/`WARNING`/`ERROR`) | `INFO` |
| `FOTOSERVER_BACKUP_DIR` | Backup-Zielverzeichnis | `/media/usb-backup` |
| `FOTOSERVER_BACKUP_KEEP` | Anzahl behaltener Backups | `7` |

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

Falls NetworkManager `wlan0` nach einem System-Update wieder übernimmt:

```bash
sudo systemctl reload NetworkManager
sudo systemctl restart fotoserver-wlan0.service
sudo systemctl restart hostapd
```

`setup-hotspot.sh` legt `/etc/NetworkManager/conf.d/fotoserver-wlan0.conf` an, das `wlan0` als `unmanaged` markiert. Diese Datei bleibt bei NM-Updates erhalten.
