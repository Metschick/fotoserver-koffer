# Fotoserver-Koffer

Modularer, offline-fähiger Fotoserver für den Raspberry Pi Hacking-Koffer.

Fotos und Videos werden drahtlos hochgeladen und im Browser angezeigt – ohne Internet, ohne Cloud.

---

## Features (V1)

- Drag & Drop Upload von Bildern und Videos (Streaming-Upload, Standard-Limit 10 GB pro Datei)
- Galerie-Ansicht im Browser
- Automatische Thumbnail-Generierung
- Lokaler WLAN-Hotspot (kein Internet nötig)
- Zugangsschutz über lokales WLAN-Hotspot-Passwort
- Kein Autostart – Fotoserver-Modus bewusst ein- und ausschaltbar
- Desktop-Shortcuts für Start/Stopp/Status (PolicyKit, kein Terminal nötig)
- Automatisches Backup (SQLite + Uploads, manuell oder täglicher Timer)

## Geplant (V2)

- Terminalfreie Steuerung via System-Tray-App (V2a)
- Admin-Interface zum Verwalten von Medien (Löschen, Serververwaltung)
- Video-Inline-Wiedergabe im Browser

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
sudo ./deploy/scripts/install.sh --source .
```

Vollständige Anleitung mit allen Optionen (Hotspot, Desktop-Shortcuts, Backup, Updates, Troubleshooting): [docs/deployment.md](docs/deployment.md)

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

`fotoserver-start.sh` gibt `wlan0` automatisch für den Hotspot frei und `fotoserver-stop.sh` gibt es beim Stoppen wieder an NetworkManager zurück (Normalbetrieb) — kein manueller Netzwerkbefehl nötig, Details in [docs/deployment.md](docs/deployment.md#wechsel-zwischen-hotspot--und-normalbetrieb).

Nach dem Start erreichbar unter: `http://192.168.4.1`

---

## Entwicklung (WSL / Linux)

Siehe [docs/development.md](docs/development.md)

---

## Architektur

Siehe [docs/architecture.md](docs/architecture.md)  
Detaillierter Planungsdokument: [plans/architektur-fotoserver-koffer.md](plans/architektur-fotoserver-koffer.md)

---

## Autor

Hauptautor: **Metschick**

Dieses Projekt wurde von Metschick entwickelt.

KI-Systeme dienten ausschließlich als Entwicklungsunterstützung und übernehmen keine Autorschaft.

---

## Lizenz

GPL-3.0 – siehe [LICENSE](LICENSE)
