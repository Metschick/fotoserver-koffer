#!/usr/bin/env bash
# Fotoserver-Koffer – Datensicherung (SQLite-DB + uploads/).
# Erzeugt ein zeitgestempeltes tar.gz-Archiv im Backup-Verzeichnis.
# Idempotent: jeder Aufruf erzeugt ein neues Archiv.
#
# Verwendung:  sudo deploy/scripts/fotoserver-backup.sh
#
# Optionale Umgebungsvariablen (können auch in /etc/environment oder systemd-Unit gesetzt werden):
#   FOTOSERVER_INSTALL_DIR=/opt/fotoserver     Installationspfad (Standard)
#   FOTOSERVER_BACKUP_DIR=<INSTALL_DIR>/backups Backup-Zielverzeichnis
#     → Kann auf gemountetes USB-Gerät zeigen, z. B. /media/usb-backup
#   FOTOSERVER_BACKUP_KEEP=7                   Anzahl behaltener Archive (0 = unbegrenzt)
#
# Automatisierung via systemd-Timer:
#   sudo systemctl enable --now fotoserver-backup.timer
set -euo pipefail

# ── Cleanup-Trap (akkumulierend, kein trap-Reset) ────────────────────────
_CLEANUP_TMPS=()
_cleanup() { rm -rf "${_CLEANUP_TMPS[@]}" 2>/dev/null || true; }
trap _cleanup EXIT

# ── Root-Check ────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Fehler: Root-Rechte erforderlich." >&2
    echo "  sudo $0" >&2
    exit 1
fi

# ── INSTALL_DIR validieren ────────────────────────────────────────────────
_RAW_INSTALL_DIR="${FOTOSERVER_INSTALL_DIR:-/opt/fotoserver}"
INSTALL_DIR="$(realpath -m "$_RAW_INSTALL_DIR")"
if [[ "$INSTALL_DIR" != "$_RAW_INSTALL_DIR" ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält '..' oder ist nicht kanonisch." >&2
    echo "  Eingabe: ${_RAW_INSTALL_DIR} → normalisiert: ${INSTALL_DIR}" >&2
    exit 1
fi
if [[ ! "$INSTALL_DIR" =~ ^/[a-zA-Z0-9._/-]+$ ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält ungültige Zeichen: ${INSTALL_DIR}" >&2
    exit 1
fi
if [[ "$INSTALL_DIR" == /home/* || "$INSTALL_DIR" == /root/* ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR darf nicht unter /home oder /root liegen." >&2
    exit 1
fi

# ── BACKUP_DIR validieren ─────────────────────────────────────────────────
_RAW_BACKUP_DIR="${FOTOSERVER_BACKUP_DIR:-${INSTALL_DIR}/backups}"
BACKUP_DIR="$(realpath -m "$_RAW_BACKUP_DIR")"
if [[ "$BACKUP_DIR" != "$_RAW_BACKUP_DIR" ]]; then
    echo "Fehler: FOTOSERVER_BACKUP_DIR enthält '..' oder ist nicht kanonisch." >&2
    echo "  Eingabe: ${_RAW_BACKUP_DIR} → normalisiert: ${BACKUP_DIR}" >&2
    exit 1
fi
if [[ ! "$BACKUP_DIR" =~ ^/[a-zA-Z0-9._/-]+$ ]]; then
    echo "Fehler: FOTOSERVER_BACKUP_DIR enthält ungültige Zeichen: ${BACKUP_DIR}" >&2
    exit 1
fi
if [[ "$BACKUP_DIR" == /home/* || "$BACKUP_DIR" == /root/* ]]; then
    echo "Fehler: FOTOSERVER_BACKUP_DIR darf nicht unter /home oder /root liegen." >&2
    echo "  Standard: ${INSTALL_DIR}/backups  oder  /media/usb-backup" >&2
    exit 1
fi

# ── BACKUP_KEEP validieren ────────────────────────────────────────────────
BACKUP_KEEP="${FOTOSERVER_BACKUP_KEEP:-7}"
if [[ ! "$BACKUP_KEEP" =~ ^[0-9]+$ ]]; then
    echo "Fehler: FOTOSERVER_BACKUP_KEEP muss eine nicht-negative Ganzzahl sein (erhalten: '${BACKUP_KEEP}')." >&2
    exit 1
fi
if [[ "$BACKUP_KEEP" -gt 9999 ]]; then
    echo "Fehler: FOTOSERVER_BACKUP_KEEP ist unrealistisch groß (max: 9999, erhalten: '${BACKUP_KEEP}')." >&2
    exit 1
fi

# ── Quellpfade prüfen ────────────────────────────────────────────────────
DB_PATH="${INSTALL_DIR}/data/fotoserver.db"
UPLOADS_DIR="${INSTALL_DIR}/uploads"

if [[ ! -f "$DB_PATH" ]]; then
    echo "Fehler: Datenbank nicht gefunden: ${DB_PATH}" >&2
    echo "  Wurde install.sh bereits ausgeführt?" >&2
    exit 1
fi
if [[ ! -d "$UPLOADS_DIR" ]]; then
    echo "Fehler: Uploads-Verzeichnis nicht gefunden: ${UPLOADS_DIR}" >&2
    exit 1
fi

# ── Voraussetzungen prüfen ────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "Fehler: python3 nicht gefunden." >&2; exit 1
fi
if ! python3 -c "import sqlite3" 2>/dev/null; then
    echo "Fehler: Python-Modul 'sqlite3' nicht verfügbar." >&2; exit 1
fi

# ── Backup-Verzeichnis anlegen ────────────────────────────────────────────
# install -d -m: atomarer Einschritt — kein Race-Window zwischen mkdir + chmod
install -d -m 700 "$BACKUP_DIR"

# ── Zeitstempel ──────────────────────────────────────────────────────────
TIMESTAMP="$(date -u '+%Y-%m-%dT%H-%M-%SZ')"
BACKUP_NAME="fotoserver-backup-${TIMESTAMP}"

echo "→ Starte Backup: ${BACKUP_NAME}"
echo "  Quelle:  ${INSTALL_DIR}"
echo "  Ziel:    ${BACKUP_DIR}"
echo ""

# ── Staging-Verzeichnis ───────────────────────────────────────────────────
TMP_STAGING="$(mktemp -d /tmp/fotoserver-backup-XXXXXX)"
_CLEANUP_TMPS+=("$TMP_STAGING")

# ── Schritt 1: SQLite-Datenbank sichern ──────────────────────────────────
echo "  [1/3] SQLite-Datenbank ..."
TMP_DB="${TMP_STAGING}/fotoserver.db"

# sqlite3.Connection.backup() implementiert die SQLite Online Backup API —
# erzeugt einen konsistenten Snapshot auch im WAL-Modus ohne Service-Stop.
# file:?mode=ro verhindert, dass die Quell-DB versehentlich verändert wird.
python3 - "$DB_PATH" "$TMP_DB" <<'PYEOF'
import sys
import sqlite3

src_path, dst_path = sys.argv[1], sys.argv[2]
src = sqlite3.connect(f"file:{src_path}?mode=ro", uri=True)
dst = sqlite3.connect(dst_path)
try:
    with dst:
        src.backup(dst)
finally:
    dst.close()
    src.close()
PYEOF

chmod 600 "$TMP_DB"
echo "     OK ($(du -sh "$TMP_DB" | cut -f1))"

# ── Schritt 2: uploads/ sichern ───────────────────────────────────────────
echo "  [2/3] uploads/ ..."
TMP_UPLOADS="${TMP_STAGING}/uploads"
mkdir -p "$TMP_UPLOADS"
# cp -a: Berechtigungen + Zeitstempel erhalten
cp -a "$UPLOADS_DIR/." "$TMP_UPLOADS/"
# Keine world-readable Dateien im Backup
chmod -R o-rwx "$TMP_UPLOADS"
UPLOADS_SIZE="$(du -sh "$TMP_UPLOADS" 2>/dev/null | cut -f1 || echo '0')"
echo "     OK (${UPLOADS_SIZE})"

# ── Schritt 3: Archiv erstellen ───────────────────────────────────────────
echo "  [3/3] Archiv erstellen ..."
# Temp-Datei im BACKUP_DIR: mv danach ist atomar (gleiches Dateisystem),
# auch wenn BACKUP_DIR ein gemountetes Gerät ist.
TMP_ARCHIVE="$(mktemp "${BACKUP_DIR}/.backup-XXXXXX.tar.gz")"
_CLEANUP_TMPS+=("$TMP_ARCHIVE")

# --owner/--group=root: Eigentümer-Metadaten im Archiv normalisieren
tar -czf "$TMP_ARCHIVE" -C "$TMP_STAGING" --owner=root --group=root .
chmod 600 "$TMP_ARCHIVE"

FINAL_ARCHIVE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
mv "$TMP_ARCHIVE" "$FINAL_ARCHIVE"
# TMP_ARCHIVE existiert nach mv nicht mehr — rm im Cleanup-Trap ist No-op (dank -f)

ARCHIVE_SIZE="$(du -sh "$FINAL_ARCHIVE" | cut -f1)"
echo "     OK: ${BACKUP_NAME}.tar.gz (${ARCHIVE_SIZE})"

# ── Schritt 4: Retention — alte Archive löschen ──────────────────────────
if [[ "$BACKUP_KEEP" -gt 0 ]]; then
    echo ""
    echo "  Aufräumen: behalte die letzten ${BACKUP_KEEP} Archive ..."
    # sort -rz / tail -zn / xargs -0: NUL-Trennung verhindert Splitting bei
    # Dateinamen mit Leerzeichen oder Newlines (GNU coreutils, auf Kali/Debian verfügbar).
    find "$BACKUP_DIR" -maxdepth 1 -name 'fotoserver-backup-*.tar.gz' -type f -print0 \
        | sort -rz \
        | tail -zn +"$((BACKUP_KEEP + 1))" \
        | xargs -0 -r rm -f --
fi

echo ""
echo "Backup abgeschlossen: ${FINAL_ARCHIVE} (${ARCHIVE_SIZE})"
