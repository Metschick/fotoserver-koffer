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
