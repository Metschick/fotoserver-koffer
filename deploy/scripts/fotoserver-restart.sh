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

# Sicherheitscheck: Skript-Verzeichnis muss root gehören
if [[ "$(stat -c '%U' "$SCRIPT_DIR")" != "root" ]]; then
    echo "Fehler: $SCRIPT_DIR gehört nicht root." >&2
    echo "  Bitte ausführen: sudo ${SCRIPT_DIR}/setup-desktop.sh" >&2
    exit 1
fi
if [[ ! -f "$STATUS_SCRIPT" ]]; then
    echo "Fehler: $STATUS_SCRIPT nicht gefunden." >&2
    exit 1
fi

# War der Fotoserver aktiv? Wenn nicht: nur starten (kein Stop nötig)
if systemctl is-active --quiet fotoserver.target; then
    echo "→ Stoppe Fotoserver-Modus ..."
    systemctl stop fotoserver.target
else
    echo "Hinweis: fotoserver.target war nicht aktiv — starte erstmalig ..."
fi

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
