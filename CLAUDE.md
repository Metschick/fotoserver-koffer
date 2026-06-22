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

Aktuelle Entwicklungsreihenfolge:

1. Grundstruktur des Projekts erstellen
2. GitHub-Repository aufbauen
3. Dokumentation erstellen
4. Backend entwickeln
5. Frontend entwickeln
6. Uploadsystem integrieren
7. Galerie integrieren
8. Deployment auf Raspberry Pi 5
9. Hotspot-, Nginx- und Systemintegration
10. Praxistests im Hacking-Koffer

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
* Album-Namen: Whitelist-Regex `^[a-zA-Z0-9_-]{1,50}$` vor Dateisystem-Verwendung
* Nginx `/uploads/`: `X-Content-Type-Options: nosniff` + `Content-Disposition: attachment`
* Upload-Limit: 100 MB pro Datei + Disk-Free-Space-Check vor Schreiben
* hostapd.conf auf Pi: `chmod 600 chown root:root`
* SQLite: `journal_mode=WAL` + `busy_timeout=5000`

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
