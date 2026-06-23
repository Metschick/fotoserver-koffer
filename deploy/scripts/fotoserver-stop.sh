#!/usr/bin/env bash
# Fotoserver-Modus stoppen: Nginx + Backend + DHCP + Hotspot
# Verwendung: sudo deploy/scripts/fotoserver-stop.sh
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

# Läuft der Fotoserver überhaupt?
if ! systemctl is-active --quiet fotoserver.target; then
    echo "Fotoserver ist nicht aktiv."
    echo ""
    "$STATUS_SCRIPT"
    exit 0
fi

echo "→ Stoppe Fotoserver-Modus ..."
systemctl stop fotoserver.target

echo ""
"$STATUS_SCRIPT"
