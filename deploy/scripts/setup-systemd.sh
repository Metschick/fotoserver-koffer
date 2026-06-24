#!/usr/bin/env bash
# systemd-Units für den Fotoserver-Koffer installieren.
# Idempotent: kann mehrfach ausgeführt werden.
# Verwendung: sudo deploy/scripts/setup-systemd.sh
# Optionale Umgebungsvariable:
#   FOTOSERVER_INSTALL_DIR=/opt/fotoserver  (Standard)
set -euo pipefail

# realpath -m normalisiert den Pfad und entfernt ".." — Schutz vor Path-Traversal.
_RAW_INSTALL_DIR="${FOTOSERVER_INSTALL_DIR:-/opt/fotoserver}"
INSTALL_DIR="$(realpath -m "$_RAW_INSTALL_DIR")"

# ── Pfad-Validierung ───────────────────────────────────────────────────────
# Nur absoluter Pfad mit sicheren Zeichen erlaubt.
# Verhindert Shell-Injection über sed-Substitution in Unit-Dateien.
if [[ ! "$INSTALL_DIR" =~ ^/[a-zA-Z0-9._/-]+$ ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält ungültige Zeichen: $INSTALL_DIR" >&2
    echo "  Erlaubt: absoluter Pfad, nur [a-zA-Z0-9._/-]" >&2
    exit 1
fi
if [[ "$INSTALL_DIR" != "$_RAW_INSTALL_DIR" ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält '..' oder ist nicht kanonisch." >&2
    echo "  Eingabe: $_RAW_INSTALL_DIR → normalisiert: $INSTALL_DIR" >&2
    exit 1
fi

# ProtectHome=yes im Service macht /home und /root unsichtbar.
# Ein INSTALL_DIR unter diesen Pfaden würde den Service beim Start stumm brechen.
if [[ "$INSTALL_DIR" == /home/* || "$INSTALL_DIR" == /root/* ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR darf nicht unter /home oder /root liegen." >&2
    echo "  Grund: fotoserver-api.service setzt ProtectHome=yes (Sicherheitshärtung)." >&2
    echo "  Standard: /opt/fotoserver" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_SRC="$(cd "$SCRIPT_DIR/../systemd" && pwd)"
SYSTEMD_DEST="/etc/systemd/system"
SERVICE_USER="fotoserver"

# ── Voraussetzungen prüfen ─────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    echo "Fehler: Dieses Skript muss als root ausgeführt werden." >&2
    echo "  sudo $0" >&2
    exit 1
fi

if ! command -v systemctl &>/dev/null; then
    echo "Fehler: systemctl nicht gefunden. systemd erforderlich." >&2
    exit 1
fi

for f in fotoserver-api.service fotoserver.target; do
    if [[ ! -f "$SYSTEMD_SRC/$f" ]]; then
        echo "Fehler: Unit-Datei nicht gefunden: $SYSTEMD_SRC/$f" >&2
        exit 1
    fi
done

# ── Systemnutzer anlegen ───────────────────────────────────────────────────

echo "→ Prüfe Systemnutzer '$SERVICE_USER' ..."
if ! id "$SERVICE_USER" &>/dev/null; then
    echo "  Lege Systemnutzer '$SERVICE_USER' an (kein Login, kein Home-Verzeichnis) ..."
    useradd \
        --system \
        --no-create-home \
        --shell /usr/sbin/nologin \
        --comment "Fotoserver-Koffer service account" \
        "$SERVICE_USER"
    echo "  Nutzer '$SERVICE_USER' angelegt."
else
    echo "  Nutzer '$SERVICE_USER' bereits vorhanden."
fi

# ── Verzeichnisse anlegen ──────────────────────────────────────────────────

echo "→ Lege Daten-Verzeichnisse an ..."
install -d -m 755 -o "$SERVICE_USER" -g "$SERVICE_USER" "$INSTALL_DIR/uploads"
install -d -m 755 -o "$SERVICE_USER" -g "$SERVICE_USER" "$INSTALL_DIR/data"
echo "  ${INSTALL_DIR}/uploads"
echo "  ${INSTALL_DIR}/data"

# ── Unit-Dateien installieren ──────────────────────────────────────────────
# Vorlagen enthalten /opt/fotoserver als Platzhalter; sed ersetzt ihn durch
# den tatsächlichen Installationspfad.

echo "→ Installiere Unit-Dateien nach $SYSTEMD_DEST ..."

for f in fotoserver-api.service fotoserver.target; do
    # Atomares Schreiben: erst in Temp-Datei, dann rename.
    # Bei Unterbrechung (Strg+C, Stromausfall) bleibt die vorhandene Unit intakt.
    TMP_UNIT="$(mktemp "$SYSTEMD_DEST/${f}.tmp.XXXXXX")"
    sed "s|/opt/fotoserver|${INSTALL_DIR}|g" "$SYSTEMD_SRC/$f" > "$TMP_UNIT"
    chmod 644 "$TMP_UNIT"
    mv -f "$TMP_UNIT" "$SYSTEMD_DEST/$f"
    echo "  $SYSTEMD_DEST/$f"
done

# ── Drop-in-Dateien installieren ──────────────────────────────────────────
# Binden nginx, hostapd und dnsmasq in den fotoserver.target-Lifecycle ein,
# ohne die Original-Unit-Dateien der Pakete zu modifizieren.

echo "→ Installiere Drop-in-Dateien ..."

for svc in nginx hostapd dnsmasq; do
    SRC_DROPIN="$SYSTEMD_SRC/${svc}.service.d/fotoserver.conf"
    DEST_DIR="$SYSTEMD_DEST/${svc}.service.d"

    if [[ ! -f "$SRC_DROPIN" ]]; then
        echo "  Warnung: Drop-in nicht gefunden, überspringe: $SRC_DROPIN" >&2
        continue
    fi

    mkdir -p "$DEST_DIR"
    TMP_DROPIN="$(mktemp "$DEST_DIR/fotoserver.tmp.XXXXXX")"
    cp "$SRC_DROPIN" "$TMP_DROPIN"
    chmod 644 "$TMP_DROPIN"
    mv -f "$TMP_DROPIN" "$DEST_DIR/fotoserver.conf"
    echo "  $DEST_DIR/fotoserver.conf"
done

# ── systemd neu laden ──────────────────────────────────────────────────────

echo "→ Lade systemd-Konfiguration neu ..."
systemctl daemon-reload

# ── Fertig ─────────────────────────────────────────────────────────────────

echo ""
echo "systemd-Units installiert."
echo ""
echo "  WICHTIG: fotoserver.target ist NICHT aktiviert (kein Autostart beim Booten)."
echo ""
echo "Nächste Schritte:"
echo "  1. .env-Datei anlegen:  cp ${INSTALL_DIR}/.env.example ${INSTALL_DIR}/.env"
echo "  2. .env absichern:      chmod 600 ${INSTALL_DIR}/.env && chown root:root ${INSTALL_DIR}/.env"
echo "     (enthält SECRET_KEY – darf nur root lesen; systemd gibt Werte als Umgebungsvariablen weiter)"
echo "  3. .env anpassen:       nano ${INSTALL_DIR}/.env"
echo "  4. Nginx einrichten:    sudo ${INSTALL_DIR}/deploy/scripts/setup-nginx.sh"
echo "  5. Fotoserver starten:  sudo systemctl start fotoserver.target"
echo "  6. Status prüfen:       sudo systemctl status fotoserver-api.service"
echo "  7. Logs ansehen:        sudo journalctl -u fotoserver-api -f"
