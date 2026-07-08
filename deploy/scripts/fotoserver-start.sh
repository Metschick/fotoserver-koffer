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

# Sicherheitscheck: Skript-Verzeichnis muss root gehören
# Verhindert Privilege Escalation falls deploy/scripts/ nicht root-owned ist.
# Setup: sudo deploy/scripts/setup-desktop.sh sichert das Verzeichnis automatisch.
if [[ "$(stat -c '%U' "$SCRIPT_DIR")" != "root" ]]; then
    echo "Fehler: $SCRIPT_DIR gehört nicht root." >&2
    echo "  Bitte ausführen: sudo ${SCRIPT_DIR}/setup-desktop.sh" >&2
    exit 1
fi
if [[ ! -f "$STATUS_SCRIPT" ]]; then
    echo "Fehler: $STATUS_SCRIPT nicht gefunden." >&2
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

# ── .env lesen (nie 'source .env' — würde Shell-Code ausführen) ───────────
_RAW_INSTALL_DIR="${FOTOSERVER_INSTALL_DIR:-/opt/fotoserver}"
INSTALL_DIR="$(realpath -m "$_RAW_INSTALL_DIR")"
ENV_FILE="$INSTALL_DIR/.env"

_env_get() {
    local key="$1" default="${2:-}"
    local val
    val="$(grep -E "^${key}[[:space:]]*=" "$ENV_FILE" 2>/dev/null \
           | tail -1 \
           | sed "s/^${key}[[:space:]]*=[[:space:]]*//" \
           | sed 's/[[:space:]]*#.*//' \
           | sed "s/^['\"]//; s/['\"]$//")"
    printf '%s' "${val:-$default}"
}

HOTSPOT_INTERFACE="$(_env_get HOTSPOT_INTERFACE 'wlan0')"
if [[ ! "$HOTSPOT_INTERFACE" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,14}$ ]]; then
    echo "Fehler: HOTSPOT_INTERFACE ist kein gültiger Interface-Name: $HOTSPOT_INTERFACE" >&2
    exit 1
fi

# ── $HOTSPOT_INTERFACE für den Hotspot von NetworkManager freigeben ───────
# Vollständiger Wechsel in den Fotoserver-Modus: hostapd braucht das Interface
# exklusiv, sonst scheitert der Start (siehe docs/deployment.md,
# "Hotspot startet nicht"). fotoserver-stop.sh entfernt diese Datei beim
# Rückwechsel in den Normalbetrieb wieder — hier idempotent neu anlegen,
# falls sie fehlt oder ein anderes Interface referenziert.
NM_CONF_DIR="/etc/NetworkManager/conf.d"
NM_CONF="$NM_CONF_DIR/99-fotoserver.conf"
NM_TEMPLATE="$INSTALL_DIR/deploy/hotspot/nm-unmanage.conf"

if [[ -d "$NM_CONF_DIR" ]]; then
    _nm_reload_needed=false
    if [[ ! -f "$NM_CONF" ]] || ! grep -q "interface-name:${HOTSPOT_INTERFACE}$" "$NM_CONF" 2>/dev/null; then
        if [[ ! -f "$NM_TEMPLATE" ]]; then
            echo "Fehler: Template nicht gefunden: $NM_TEMPLATE" >&2
            exit 1
        fi
        echo "→ Gebe $HOTSPOT_INTERFACE für den Hotspot frei (NetworkManager unmanaged) ..."
        TMP_NM="$(mktemp /tmp/fotoserver-nm-XXXXXX.conf)"
        trap 'rm -f "$TMP_NM"' EXIT
        sed "s|__INTERFACE__|${HOTSPOT_INTERFACE}|g" "$NM_TEMPLATE" > "$TMP_NM"
        install -m 644 -o root -g root "$TMP_NM" "$NM_CONF"
        rm -f "$TMP_NM"
        trap - EXIT
        _nm_reload_needed=true
    fi

    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        if [[ "$_nm_reload_needed" == true ]]; then
            systemctl reload NetworkManager 2>/dev/null || systemctl restart NetworkManager
        fi

        # Ein reload allein löst noch keine bereits AKTIVE Verbindung auf
        # $HOTSPOT_INTERFACE (z. B. normales WLAN im Normalbetrieb): NetworkManager
        # hält sie, bis explizit getrennt wird. Ohne das würde hostapd zwar
        # kurzzeitig "AP-ENABLED" melden, NetworkManager übernimmt das Interface
        # aber gleich danach zurück (race condition, hostapd bemerkt es nicht und
        # bleibt "active" obwohl kein echter Access Point mehr läuft). Daher hier
        # explizit trennen und auf "unmanaged" warten, bevor hostapd startet.
        if command -v nmcli &>/dev/null; then
            nmcli device disconnect "$HOTSPOT_INTERFACE" &>/dev/null || true
            for _ in {1..10}; do
                _nm_state="$(nmcli -t -f GENERAL.STATE device show "$HOTSPOT_INTERFACE" 2>/dev/null | cut -d: -f2)"
                if [[ "$_nm_state" == "10" ]]; then
                    break
                fi
                sleep 0.5
            done
        fi
    fi
else
    echo "Warnung: $NM_CONF_DIR nicht gefunden — NetworkManager-Freigabe übersprungen." >&2
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
