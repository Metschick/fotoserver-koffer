#!/usr/bin/env bash
# Nginx einmalig für Fotoserver konfigurieren.
# Idempotent: kann mehrfach ausgeführt werden.
# Verwendung: sudo deploy/scripts/setup-nginx.sh
# Optionale Umgebungsvariable:
#   FOTOSERVER_INSTALL_DIR=/opt/fotoserver  (Standard)
set -euo pipefail

INSTALL_DIR="${FOTOSERVER_INSTALL_DIR:-/opt/fotoserver}"

# ── Pfad-Validierung ───────────────────────────────────────────────────────
# Nur absoluter Pfad mit sicheren Zeichen erlaubt.
# Verhindert Nginx-Config-Injection über sed-Substitution.
if [[ ! "$INSTALL_DIR" =~ ^/[a-zA-Z0-9._/-]+$ ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält ungültige Zeichen: $INSTALL_DIR" >&2
    echo "  Erlaubt: absoluter Pfad, nur [a-zA-Z0-9._/-]" >&2
    exit 1
fi

CONF_TEMPLATE="$INSTALL_DIR/deploy/nginx/fotoserver.conf"
SITES_AVAILABLE="/etc/nginx/sites-available/fotoserver"
SITES_ENABLED="/etc/nginx/sites-enabled/fotoserver"
DEFAULT_ENABLED="/etc/nginx/sites-enabled/default"
BACKUP="${SITES_AVAILABLE}.bak"

# Temp-Datei für atomares Schreiben (wird bei EXIT automatisch entfernt)
TMP_CONF="$(mktemp /tmp/fotoserver-nginx-XXXXXX.conf)"
trap 'rm -f "$TMP_CONF"' EXIT

# ── Voraussetzungen prüfen ─────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    echo "Fehler: Dieses Skript muss als root ausgeführt werden." >&2
    echo "  sudo $0" >&2
    exit 1
fi

if ! command -v nginx &>/dev/null; then
    echo "Fehler: nginx ist nicht installiert." >&2
    echo "  sudo apt install nginx" >&2
    exit 1
fi

if [[ ! -f "$CONF_TEMPLATE" ]]; then
    echo "Fehler: Konfigurationsvorlage nicht gefunden: $CONF_TEMPLATE" >&2
    exit 1
fi

if [[ ! -d /etc/nginx/sites-available ]]; then
    echo "Fehler: /etc/nginx/sites-available nicht gefunden." >&2
    echo "  Kali/Debian-Nginx-Paket vorausgesetzt." >&2
    exit 1
fi

# ── Konfiguration aufbauen und vorab validieren ────────────────────────────

echo "→ Verarbeite Konfigurationsvorlage ..."
sed "s|/opt/fotoserver|${INSTALL_DIR}|g" "$CONF_TEMPLATE" > "$TMP_CONF"
chmod 644 "$TMP_CONF"

# Bestehende Konfiguration sichern, bevor die neue geschrieben wird
if [[ -f "$SITES_AVAILABLE" ]]; then
    echo "→ Sichere bestehende Konfiguration nach ${BACKUP} ..."
    cp "$SITES_AVAILABLE" "$BACKUP"
fi

# Neue Konfiguration erst jetzt schreiben
echo "→ Installiere Nginx-Konfiguration nach $SITES_AVAILABLE ..."
cp "$TMP_CONF" "$SITES_AVAILABLE"

# Konfiguration validieren – bei Fehler sofort auf Backup zurückfallen
echo "→ Teste Nginx-Konfiguration ..."
if ! nginx -t 2>&1; then
    echo "" >&2
    echo "Fehler: Nginx-Konfigurationstest fehlgeschlagen." >&2
    if [[ -f "$BACKUP" ]]; then
        echo "  Stelle Backup wieder her: $BACKUP" >&2
        cp "$BACKUP" "$SITES_AVAILABLE"
    else
        echo "  Kein Backup vorhanden – bitte $SITES_AVAILABLE manuell prüfen." >&2
    fi
    exit 1
fi

# ── Nginx-Site aktivieren ──────────────────────────────────────────────────

echo "→ Aktiviere Site ..."
ln -sf "$SITES_AVAILABLE" "$SITES_ENABLED"

# Standard-Site deaktivieren, damit Port 80 frei ist
if [[ -L "$DEFAULT_ENABLED" ]]; then
    echo "→ Deaktiviere Standard-Nginx-Site ..."
    rm -f "$DEFAULT_ENABLED"
fi

# ── Fertig ─────────────────────────────────────────────────────────────────

echo ""
echo "Nginx konfiguriert."
echo "  Site:      $SITES_AVAILABLE"
echo "  Frontend:  ${INSTALL_DIR}/frontend/dist"
echo "  API-Proxy: http://127.0.0.1:8000"
echo ""
echo "Nginx startet automatisch mit: sudo systemctl start fotoserver.target"
echo "Zum manuellen Test:            sudo systemctl start nginx"
