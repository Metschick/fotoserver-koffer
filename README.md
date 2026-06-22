# Fotoserver-Koffer

Modularer, offline-fähiger Fotoserver für den Raspberry Pi Hacking-Koffer.

Fotos und Videos werden drahtlos hochgeladen und im Browser angezeigt – ohne Internet, ohne Cloud.

---

## Features

- Drag & Drop Upload von Bildern und Videos
- Galerie-Ansicht im Browser
- Automatische Thumbnail-Generierung
- Lokaler WLAN-Hotspot (kein Internet nötig)
- Passwortgeschützter Zugang
- Admin-Interface zum Verwalten von Medien
- Terminalfrei bedienbar (V1.5+)
- Kein Autostart – Fotoserver-Modus bewusst ein- und ausschaltbar

---

## Systemvoraussetzungen

- Raspberry Pi 5 mit Kali Linux (ARM64)
- Python 3.11+
- `nginx`, `hostapd`, `dnsmasq`, `ffmpeg`, `libmagic1`

---

## Installation

```bash
git clone https://github.com/Metschick/fotoserver-koffer.git /opt/fotoserver
cd /opt/fotoserver
cp .env.example .env
# .env anpassen (Passwörter, SSID etc.)
sudo ./deploy/scripts/install.sh
```

---

## Fotoserver starten und stoppen

```bash
# Fotoserver-Modus starten (Hotspot + Webserver)
sudo ./deploy/scripts/fotoserver-start.sh

# Status prüfen
./deploy/scripts/fotoserver-status.sh

# Fotoserver-Modus stoppen
sudo ./deploy/scripts/fotoserver-stop.sh
```

Nach dem Start erreichbar unter: `http://192.168.4.1`

---

## Entwicklung (WSL / Linux)

Siehe [docs/development.md](docs/development.md)

---

## Architektur

Siehe [docs/architecture.md](docs/architecture.md)  
Detaillierter Planungsdokument: [plans/architektur-fotoserver-koffer.md](plans/architektur-fotoserver-koffer.md)

---

## Lizenz

MIT – siehe [LICENSE](LICENSE)
