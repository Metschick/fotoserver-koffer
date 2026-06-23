#!/usr/bin/env bash
# Fotoserver neu starten — stoppt alle Dienste und startet sie in korrekter Reihenfolge neu.
# Verwendung: sudo deploy/scripts/fotoserver-restart.sh
# Typischer Anlass: Code-Update des Backends, Nginx-Konfigurationsänderung.
# Nur Backend neu starten (ohne Hotspot-Unterbrechung):
#   sudo systemctl restart fotoserver-api.service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_SCRIPT="$SCRIPT_DIR/fotoserver-status.sh"

if [[ $EUID -ne 0 ]]; then
    echo "Fehler: Root-Rechte erforderlich." >&2
    echo "  sudo $0" >&2
    exit 1
fi

# Sicherheitscheck: Status-Skript muss root gehören
if [[ ! -f "$STATUS_SCRIPT" ]]; then
    echo "Fehler: $STATUS_SCRIPT nicht gefunden." >&2
    exit 1
fi
if [[ "$(stat -c '%U' "$STATUS_SCRIPT")" != "root" ]]; then
    echo "Fehler: $STATUS_SCRIPT gehört nicht root." >&2
    echo "  Bitte Verzeichnisrechte prüfen: chown root:root $STATUS_SCRIPT" >&2
    exit 1
fi

# Neustart setzt voraus, dass der Fotoserver läuft
if ! systemctl is-active --quiet fotoserver.target; then
    echo "Fehler: fotoserver.target ist nicht aktiv." >&2
    echo "  Zum Starten: sudo $SCRIPT_DIR/fotoserver-start.sh" >&2
    exit 1
fi

echo "→ Stoppe Fotoserver-Modus ..."
systemctl stop fotoserver.target

echo "→ Starte Fotoserver-Modus ..."
systemctl start fotoserver.target

echo "→ Warte auf Dienste ..."
for _ in {1..10}; do
    if systemctl is-active --quiet fotoserver.target; then
        break
    fi
    sleep 1
done

echo ""
"$STATUS_SCRIPT"

# Fehler zurückmelden wenn das Target nicht aktiv wurde
if ! systemctl is-active --quiet fotoserver.target; then
    echo "Fehler: fotoserver.target hat den Status 'active' nicht erreicht." >&2
    echo "  Details: sudo journalctl -u fotoserver-api --since '-60s'" >&2
    exit 1
fi
