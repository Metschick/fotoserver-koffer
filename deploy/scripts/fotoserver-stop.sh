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

# Läuft der Fotoserver überhaupt?
if systemctl is-active --quiet fotoserver.target; then
    echo "→ Stoppe Fotoserver-Modus ..."
    systemctl stop fotoserver.target
else
    echo "Fotoserver ist nicht aktiv."
fi

# ── wlan0 zurück an NetworkManager geben (voller Rückwechsel in den
#    Normalbetrieb) ─────────────────────────────────────────────────────────
# Idempotent: läuft auch wenn fotoserver.target oben bereits inaktiv war
# (z. B. erneuter Klick auf "Stop"), damit ein Laie sich nie auf den vorherigen
# internen Zustand verlassen muss. Kein manueller Befehl danach nötig — siehe
# docs/deployment.md, "Wechsel zwischen Hotspot- und Normalbetrieb".
NM_CONF="/etc/NetworkManager/conf.d/99-fotoserver.conf"
if [[ -f "$NM_CONF" ]]; then
    _iface="$(sed -n 's/.*interface-name:\(.*\)/\1/p' "$NM_CONF" | head -1)"
    if [[ -z "$_iface" ]]; then
        _iface="Hotspot-Interface"
    fi
    echo "→ Gebe $_iface an NetworkManager zurück (Normalbetrieb) ..."
    rm -f "$NM_CONF"
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        systemctl reload NetworkManager 2>/dev/null || systemctl restart NetworkManager
    fi
fi

echo ""
"$STATUS_SCRIPT"
