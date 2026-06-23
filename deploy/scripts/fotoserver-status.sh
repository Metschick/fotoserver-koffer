#!/usr/bin/env bash
# Status aller Fotoserver-Dienste anzeigen
# Verwendung: deploy/scripts/fotoserver-status.sh  (kein Root nötig)
# Kein set -euo pipefail: systemctl is-active gibt non-zero zurück wenn Dienst inaktiv

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES=(hostapd.service dnsmasq.service fotoserver-api.service nginx.service)

# Status eines einzelnen Dienstes ermitteln und ausgeben
show_service() {
    local svc="$1"
    local state
    # is-active gibt den Textstatus zurück ("active", "inactive", "failed", "activating", ...)
    state=$(systemctl is-active "$svc" 2>/dev/null || true)
    printf "  %-30s %s\n" "$svc" "$state"
}

echo ""
echo "Fotoserver-Status"
echo "─────────────────────────────────────────────"
for svc in "${SERVICES[@]}"; do
    show_service "$svc"
done
echo "─────────────────────────────────────────────"

TARGET_STATE=$(systemctl is-active fotoserver.target 2>/dev/null || true)
printf "  %-30s %s\n" "fotoserver.target" "$TARGET_STATE"
echo ""

if [[ "$TARGET_STATE" == "active" ]]; then
    echo "Logs:       sudo journalctl -u fotoserver-api -f"
    echo "Stoppen:    sudo $SCRIPT_DIR/fotoserver-stop.sh"
else
    echo "Starten:    sudo $SCRIPT_DIR/fotoserver-start.sh"
fi
echo ""
