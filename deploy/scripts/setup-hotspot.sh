#!/usr/bin/env bash
# Hotspot-Konfiguration für Fotoserver-Koffer einrichten.
# Liest HOTSPOT_*-Werte aus .env, generiert hostapd- und dnsmasq-Konfiguration,
# konfiguriert NetworkManager und installiert fotoserver-wlan0.service.
# Idempotent: kann mehrfach ausgeführt werden.
#
# Verwendung: sudo deploy/scripts/setup-hotspot.sh
# Optionale Umgebungsvariablen:
#   FOTOSERVER_INSTALL_DIR=/opt/fotoserver  (Standard)
#   FOTOSERVER_GITHUB_REPO=Metschick/fotoserver-koffer  (Standard)
set -euo pipefail

# ── Pfad-Validierung ───────────────────────────────────────────────────────
_RAW_INSTALL_DIR="${FOTOSERVER_INSTALL_DIR:-/opt/fotoserver}"
INSTALL_DIR="$(realpath -m "$_RAW_INSTALL_DIR")"

if [[ ! "$INSTALL_DIR" =~ ^/[a-zA-Z0-9._/-]+$ ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält ungültige Zeichen." >&2; exit 1
fi
if [[ "$INSTALL_DIR" != "$_RAW_INSTALL_DIR" ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält '..' oder ist nicht kanonisch." >&2
    echo "  Eingabe: $_RAW_INSTALL_DIR → normalisiert: $INSTALL_DIR" >&2; exit 1
fi
if [[ "$INSTALL_DIR" == /home/* || "$INSTALL_DIR" == /root/* ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR darf nicht unter /home oder /root liegen." >&2; exit 1
fi

GITHUB_REPO="${FOTOSERVER_GITHUB_REPO:-Metschick/fotoserver-koffer}"
if [[ ! "$GITHUB_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    echo "Fehler: Ungültiges FOTOSERVER_GITHUB_REPO: $GITHUB_REPO" >&2; exit 1
fi

HOTSPOT_DIR="$INSTALL_DIR/deploy/hotspot"

# ── Root-Check ────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Fehler: Root-Rechte erforderlich." >&2
    echo "  sudo $0" >&2; exit 1
fi

# ── Temp-Datei-Cleanup ────────────────────────────────────────────────────
TMP_FILES=()
trap 'rm -f "${TMP_FILES[@]}" 2>/dev/null || true' EXIT

# ── Voraussetzungen prüfen ─────────────────────────────────────────────────
for cmd in hostapd dnsmasq ip python3 systemctl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Fehler: $cmd nicht gefunden. Bitte installieren:" >&2
        echo "  sudo apt install hostapd dnsmasq iproute2 python3" >&2
        exit 1
    fi
done

ENV_FILE="$INSTALL_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Fehler: .env nicht gefunden: $ENV_FILE" >&2
    echo "  Bitte zuerst install.sh ausführen oder .env manuell anlegen." >&2
    exit 1
fi

for tpl in hostapd.conf.template dnsmasq.conf.template nm-unmanage.conf \
           fotoserver-wlan0.service.template; do
    if [[ ! -f "$HOTSPOT_DIR/$tpl" ]]; then
        echo "Fehler: Template nicht gefunden: $HOTSPOT_DIR/$tpl" >&2; exit 1
    fi
done

# ── .env-Werte lesen (nie 'source .env' — würde Shell-Code ausführen) ─────
_env_get() {
    local key="$1" default="${2:-}"
    local val
    # Letzten Eintrag nehmen, Inline-Kommentar und Anführungszeichen entfernen
    val="$(grep -E "^${key}[[:space:]]*=" "$ENV_FILE" 2>/dev/null \
           | tail -1 \
           | sed "s/^${key}[[:space:]]*=[[:space:]]*//" \
           | sed 's/[[:space:]]*#.*//' \
           | sed "s/^['\"]//; s/['\"]$//")"
    printf '%s' "${val:-$default}"
}

HOTSPOT_SSID="$(_env_get HOTSPOT_SSID 'FotoServer')"
HOTSPOT_PASSWORD="$(_env_get HOTSPOT_PASSWORD '')"
HOTSPOT_INTERFACE="$(_env_get HOTSPOT_INTERFACE 'wlan0')"
HOTSPOT_IP="$(_env_get HOTSPOT_IP '192.168.4.1')"
HOTSPOT_COUNTRY="$(_env_get HOTSPOT_COUNTRY 'DE')"

# ── Validierungen ──────────────────────────────────────────────────────────

# SSID: 1–32 druckbare ASCII-Zeichen (IEEE 802.11)
if [[ -z "$HOTSPOT_SSID" || ${#HOTSPOT_SSID} -gt 32 ]]; then
    echo "Fehler: HOTSPOT_SSID muss 1–32 Zeichen lang sein." >&2; exit 1
fi
if [[ ! "$HOTSPOT_SSID" =~ ^[[:print:]]+$ ]]; then
    echo "Fehler: HOTSPOT_SSID enthält ungültige Zeichen." >&2; exit 1
fi

# Passwort: WPA2 verlangt 8–63 druckbare ASCII-Zeichen
if [[ "$HOTSPOT_PASSWORD" == "CHANGE_ME" || -z "$HOTSPOT_PASSWORD" ]]; then
    echo "Fehler: HOTSPOT_PASSWORD in .env muss gesetzt werden (nicht CHANGE_ME)." >&2
    echo "  Generieren: pwgen -s 16 1  oder openssl rand -base64 12" >&2; exit 1
fi
if [[ ${#HOTSPOT_PASSWORD} -lt 8 || ${#HOTSPOT_PASSWORD} -gt 63 ]]; then
    echo "Fehler: HOTSPOT_PASSWORD muss 8–63 Zeichen lang sein (WPA2-Anforderung)." >&2; exit 1
fi
if [[ ! "$HOTSPOT_PASSWORD" =~ ^[[:print:]]+$ ]]; then
    echo "Fehler: HOTSPOT_PASSWORD enthält nicht-druckbare Zeichen." >&2; exit 1
fi

# Interface: gültiger Linux-Interface-Name
if [[ ! "$HOTSPOT_INTERFACE" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,14}$ ]]; then
    echo "Fehler: HOTSPOT_INTERFACE ist kein gültiger Interface-Name: $HOTSPOT_INTERFACE" >&2; exit 1
fi

# IP: Format und Oktet-Bereich prüfen
if [[ ! "$HOTSPOT_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Fehler: HOTSPOT_IP ist keine gültige IPv4-Adresse: $HOTSPOT_IP" >&2; exit 1
fi
IFS='.' read -r _o1 _o2 _o3 _o4 <<< "$HOTSPOT_IP"
if (( _o1 > 254 || _o2 > 255 || _o3 > 255 || _o4 < 1 || _o4 > 254 )); then
    echo "Fehler: HOTSPOT_IP enthält ungültige Oktet-Werte (jedes Oktet 0–255, letztes 1–254): $HOTSPOT_IP" >&2; exit 1
fi

# Land: 2 Großbuchstaben (ISO 3166-1 alpha-2)
if [[ ! "$HOTSPOT_COUNTRY" =~ ^[A-Z]{2}$ ]]; then
    echo "Fehler: HOTSPOT_COUNTRY muss 2 Großbuchstaben sein (z.B. DE, AT, CH): $HOTSPOT_COUNTRY" >&2; exit 1
fi

# DHCP-Bereich aus der IP-Basis ableiten
HOTSPOT_SUBNET="${HOTSPOT_IP%.*}"   # z.B. 192.168.4
DHCP_START="${HOTSPOT_SUBNET}.10"
DHCP_END="${HOTSPOT_SUBNET}.100"

# Sicherstellen, dass die Pi-IP nicht im DHCP-Pool liegt (würde Adresskonflikt verursachen)
_last_octet="${HOTSPOT_IP##*.}"
if (( _last_octet >= 10 && _last_octet <= 100 )); then
    echo "Fehler: HOTSPOT_IP (letztes Oktet .$_last_octet) liegt im DHCP-Pool (.10–.100)." >&2
    echo "  Wähle eine IP mit letztem Oktet < 10 oder > 100, z.B. ${HOTSPOT_SUBNET}.1" >&2; exit 1
fi

echo ""
echo "Hotspot-Konfiguration:"
echo "  SSID:       $HOTSPOT_SSID"
echo "  Interface:  $HOTSPOT_INTERFACE"
echo "  IP:         $HOTSPOT_IP/24"
echo "  DHCP:       $DHCP_START – $DHCP_END"
echo "  Land:       $HOTSPOT_COUNTRY"
echo ""

# ── 1. hostapd.conf generieren ─────────────────────────────────────────────
# Das Passwort wird über Umgebungsvariable übergeben (nicht als Argument),
# damit es nicht in 'ps aux' sichtbar ist.
echo "→ Generiere hostapd-Konfiguration ..."

TMP_HOSTAPD="$(mktemp /tmp/fotoserver-hostapd-XXXXXX.conf)"
TMP_FILES+=("$TMP_HOSTAPD")
chmod 600 "$TMP_HOSTAPD"

FOTOSERVER_HOTSPOT_PW="$HOTSPOT_PASSWORD" \
python3 - "$HOTSPOT_DIR/hostapd.conf.template" \
          "$HOTSPOT_INTERFACE" "$HOTSPOT_SSID" "$HOTSPOT_COUNTRY" > "$TMP_HOSTAPD" <<'PYEOF'
import sys, os
tpl_file, interface, ssid, country = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
password = os.environ['FOTOSERVER_HOTSPOT_PW']
with open(tpl_file) as f:
    result = f.read()
result = (result
    .replace('__INTERFACE__', interface)
    .replace('__SSID__',      ssid)
    .replace('__PASSWORD__',  password)
    .replace('__COUNTRY__',   country))
sys.stdout.write(result)
PYEOF

install -d -m 755 /etc/hostapd
# install -m 600: atomares Schreiben + korrekte Berechtigungen in einem Schritt
install -m 600 -o root -g root "$TMP_HOSTAPD" /etc/hostapd/fotoserver.conf
echo "  /etc/hostapd/fotoserver.conf (chmod 600, root:root)"

# ── 2. /etc/default/hostapd konfigurieren ─────────────────────────────────
echo "→ Konfiguriere /etc/default/hostapd ..."
HOSTAPD_DEFAULT="/etc/default/hostapd"
TMP_HDEF="$(mktemp /tmp/fotoserver-hdef-XXXXXX)"
TMP_FILES+=("$TMP_HDEF")

if [[ -f "$HOSTAPD_DEFAULT" ]]; then
    # Alle bestehenden DAEMON_CONF-Zeilen entfernen (kommentiert oder nicht),
    # dann die neue hinzufügen — verhindert doppelte Einträge beim Re-Run.
    # Verankerte Regex verhindert, dass hypothetische DAEMON_CONF_OPTIONS-Zeilen gelöscht werden.
    grep -Ev '^[[:space:]]*(#[[:space:]]*)?DAEMON_CONF[[:space:]]*=' "$HOSTAPD_DEFAULT" > "$TMP_HDEF" || true
else
    touch "$TMP_HDEF"
fi
echo 'DAEMON_CONF=/etc/hostapd/fotoserver.conf' >> "$TMP_HDEF"
# install ist atomarer als mv bei /tmp (tmpfs) → /etc (ext4)-Übergängen auf dem Pi
install -m 644 -o root -g root "$TMP_HDEF" "$HOSTAPD_DEFAULT"
echo "  /etc/default/hostapd (DAEMON_CONF gesetzt)"

# ── 3. dnsmasq.conf generieren ─────────────────────────────────────────────
echo "→ Generiere dnsmasq-Konfiguration ..."

TMP_DNSMASQ="$(mktemp /tmp/fotoserver-dnsmasq-XXXXXX.conf)"
TMP_FILES+=("$TMP_DNSMASQ")

sed \
    -e "s|__INTERFACE__|${HOTSPOT_INTERFACE}|g" \
    -e "s|__HOTSPOT_IP__|${HOTSPOT_IP}|g" \
    -e "s|__DHCP_START__|${DHCP_START}|g" \
    -e "s|__DHCP_END__|${DHCP_END}|g" \
    "$HOTSPOT_DIR/dnsmasq.conf.template" > "$TMP_DNSMASQ"
chmod 644 "$TMP_DNSMASQ"

install -d -m 755 /etc/dnsmasq.d
install -m 644 -o root -g root "$TMP_DNSMASQ" /etc/dnsmasq.d/fotoserver.conf
echo "  /etc/dnsmasq.d/fotoserver.conf"

# ── 4. NetworkManager: Interface unmanaged setzen ─────────────────────────
echo "→ Konfiguriere NetworkManager ..."
NM_CONF_DIR="/etc/NetworkManager/conf.d"

if [[ -d "$NM_CONF_DIR" ]]; then
    TMP_NM="$(mktemp /tmp/fotoserver-nm-XXXXXX.conf)"
    TMP_FILES+=("$TMP_NM")

    sed "s|__INTERFACE__|${HOTSPOT_INTERFACE}|g" \
        "$HOTSPOT_DIR/nm-unmanage.conf" > "$TMP_NM"
    install -m 644 -o root -g root "$TMP_NM" "${NM_CONF_DIR}/99-fotoserver.conf"
    echo "  ${NM_CONF_DIR}/99-fotoserver.conf"
else
    echo "  Warnung: /etc/NetworkManager/conf.d nicht gefunden." >&2
    echo "  Stelle manuell sicher, dass $HOTSPOT_INTERFACE nicht von NetworkManager verwaltet wird." >&2
fi

# ── 5. fotoserver-wlan0.service installieren ──────────────────────────────
echo "→ Installiere fotoserver-wlan0.service ..."

TMP_WLAN_SVC="$(mktemp /tmp/fotoserver-wlan0-svc-XXXXXX)"
TMP_FILES+=("$TMP_WLAN_SVC")

sed \
    -e "s|__INTERFACE__|${HOTSPOT_INTERFACE}|g" \
    -e "s|__HOTSPOT_IP__|${HOTSPOT_IP}|g" \
    -e "s|__GITHUB_REPO__|${GITHUB_REPO}|g" \
    "$HOTSPOT_DIR/fotoserver-wlan0.service.template" > "$TMP_WLAN_SVC"
install -m 644 -o root -g root "$TMP_WLAN_SVC" /etc/systemd/system/fotoserver-wlan0.service
echo "  /etc/systemd/system/fotoserver-wlan0.service"

# ── 6. systemd daemon-reload ───────────────────────────────────────────────
echo "→ Lade systemd-Konfiguration neu ..."
systemctl daemon-reload

# ── 7. NetworkManager neu laden ───────────────────────────────────────────
# reload (SIGHUP) liest conf.d neu ohne bestehende Verbindungen zu unterbrechen.
# Nur wenn reload nicht unterstützt wird (ältere NM-Versionen), restart als Fallback.
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "→ Lade NetworkManager-Konfiguration neu (unmanaged-devices aktivieren) ..."
    if ! systemctl reload NetworkManager 2>/dev/null; then
        echo "  Reload nicht verfügbar — Neustart (unterbricht kurz bestehende Verbindungen) ..."
        systemctl restart NetworkManager
    fi
fi

# ── Fertig ─────────────────────────────────────────────────────────────────
echo ""
echo "Hotspot-Konfiguration abgeschlossen."
echo ""
echo "  hostapd:   /etc/hostapd/fotoserver.conf  (chmod 600)"
echo "  dnsmasq:   /etc/dnsmasq.d/fotoserver.conf"
echo "  NM:        /etc/NetworkManager/conf.d/99-fotoserver.conf"
echo "  systemd:   /etc/systemd/system/fotoserver-wlan0.service"
echo ""
echo "WICHTIG: Nach einem neuen Login ist die NM-Änderung aktiv."
echo "         Falls $HOTSPOT_INTERFACE bereits von NM verwaltet wird:"
echo "           nmcli device disconnect $HOTSPOT_INTERFACE"
echo ""
echo "Hotspot starten:"
echo "  sudo $INSTALL_DIR/deploy/scripts/fotoserver-start.sh"
echo ""
echo "Status prüfen:"
echo "  $INSTALL_DIR/deploy/scripts/fotoserver-status.sh"
