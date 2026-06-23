#!/usr/bin/env bash
# Fotoserver-Modus starten: Hotspot + DHCP + Backend + Nginx
# Verwendung: sudo deploy/scripts/fotoserver-start.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_SCRIPT="$SCRIPT_DIR/fotoserver-status.sh"

if [[ $EUID -ne 0 ]]; then
    echo "Fehler: Root-Rechte erforderlich." >&2
    echo "  sudo $0" >&2
    exit 1
fi

# Sicherheitscheck: Status-Skript muss root gehören
# Verhindert Privilege Escalation falls deploy/scripts/ nicht root-owned ist
if [[ ! -f "$STATUS_SCRIPT" ]]; then
    echo "Fehler: $STATUS_SCRIPT nicht gefunden." >&2
    exit 1
fi
if [[ "$(stat -c '%U' "$STATUS_SCRIPT")" != "root" ]]; then
    echo "Fehler: $STATUS_SCRIPT gehört nicht root." >&2
    echo "  Bitte Verzeichnisrechte prüfen: chown root:root $STATUS_SCRIPT" >&2
    exit 1
fi

# Ist das Target in systemd bekannt?
if ! systemctl cat fotoserver.target &>/dev/null; then
    echo "Fehler: fotoserver.target nicht gefunden." >&2
    echo "  Bitte zuerst ausführen: sudo ${SCRIPT_DIR}/setup-systemd.sh" >&2
    exit 1
fi

# Idempotenz: bereits aktiv?
if systemctl is-active --quiet fotoserver.target; then
    echo "Fotoserver läuft bereits."
    echo ""
    "$STATUS_SCRIPT"
    exit 0
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
