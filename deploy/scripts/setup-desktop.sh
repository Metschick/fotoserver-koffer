#!/usr/bin/env bash
# Desktop-Shortcuts und PolicyKit-Regel für den Fotoserver-Koffer installieren.
# Idempotent: kann mehrfach ausgeführt werden.
# Verwendung: sudo deploy/scripts/setup-desktop.sh [DESKTOP_USER]
# Argumente:
#   DESKTOP_USER  Benutzername des Desktop-Nutzers (optional).
#                 Wenn angegeben, werden Shortcuts auch auf dessen Desktop kopiert.
#                 Muss ein gültiger lokaler Benutzername sein.
# Optionale Umgebungsvariable:
#   FOTOSERVER_INSTALL_DIR=/opt/fotoserver  (Standard)
set -euo pipefail

# ── Pfad-Validierung ───────────────────────────────────────────────────────
# Normalisierung via realpath verhindert Path-Traversal durch ".." im Pfad.
_RAW_INSTALL_DIR="${FOTOSERVER_INSTALL_DIR:-/opt/fotoserver}"
INSTALL_DIR="$(realpath -m "$_RAW_INSTALL_DIR")"

if [[ ! "$INSTALL_DIR" =~ ^/[a-zA-Z0-9._/-]+$ ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält ungültige Zeichen: $INSTALL_DIR" >&2
    echo "  Erlaubt: absoluter Pfad, nur [a-zA-Z0-9._/-]" >&2
    exit 1
fi
# Verzeichnis darf kein ".." enthalten (wurde durch realpath normalisiert —
# wenn Eingabe und normalisierter Pfad abweichen, gab es "..")
if [[ "$INSTALL_DIR" != "$_RAW_INSTALL_DIR" ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält '..' oder ist nicht kanonisch." >&2
    echo "  Eingabe: $_RAW_INSTALL_DIR → normalisiert: $INSTALL_DIR" >&2
    exit 1
fi
if [[ "$INSTALL_DIR" == /home/* || "$INSTALL_DIR" == /root/* ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR darf nicht unter /home oder /root liegen." >&2
    exit 1
fi

# Benutzername validieren (nur wenn angegeben)
DESKTOP_USER="${1:-}"
if [[ -n "$DESKTOP_USER" ]]; then
    if [[ ! "$DESKTOP_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        echo "Fehler: Ungültiger Benutzername: $DESKTOP_USER" >&2
        echo "  Erlaubt: Kleinbuchstaben, Ziffern, _ und - (max. 32 Zeichen)" >&2
        exit 1
    fi
    if ! id "$DESKTOP_USER" &>/dev/null; then
        echo "Fehler: Benutzer '$DESKTOP_USER' existiert nicht." >&2
        exit 1
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_SRC="$(cd "$SCRIPT_DIR/../desktop" && pwd)"
POLKIT_DEST="/etc/polkit-1/rules.d"
APPLICATIONS_DEST="/usr/share/applications"
ADMIN_GROUP="fotoserver-admin"

DESKTOP_FILES=(
    fotoserver-start.desktop
    fotoserver-stop.desktop
    fotoserver-status.desktop
    fotoserver-restart.desktop
)

# Temp-Dateien werden beim EXIT automatisch entfernt
TMP_FILES=()
trap 'rm -f "${TMP_FILES[@]}"' EXIT

# ── Voraussetzungen prüfen ─────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    echo "Fehler: Root-Rechte erforderlich." >&2
    echo "  sudo $0 [DESKTOP_USER]" >&2
    exit 1
fi

if [[ ! -d "$POLKIT_DEST" ]]; then
    echo "Fehler: $POLKIT_DEST nicht gefunden." >&2
    echo "  Kali/Debian: sudo apt install policykit-1" >&2
    exit 1
fi

if [[ ! -f "$DESKTOP_SRC/50-fotoserver.rules" ]]; then
    echo "Fehler: PolicyKit-Regel nicht gefunden: $DESKTOP_SRC/50-fotoserver.rules" >&2
    exit 1
fi

for f in "${DESKTOP_FILES[@]}"; do
    if [[ ! -f "$DESKTOP_SRC/$f" ]]; then
        echo "Fehler: Desktop-Datei nicht gefunden: $DESKTOP_SRC/$f" >&2
        exit 1
    fi
done

# ── Admin-Gruppe anlegen ───────────────────────────────────────────────────

echo "→ Prüfe Gruppe '$ADMIN_GROUP' ..."
if ! getent group "$ADMIN_GROUP" &>/dev/null; then
    echo "  Lege Gruppe '$ADMIN_GROUP' an ..."
    groupadd "$ADMIN_GROUP"
    echo "  Gruppe '$ADMIN_GROUP' angelegt."
else
    echo "  Gruppe '$ADMIN_GROUP' bereits vorhanden."
fi

if [[ -n "$DESKTOP_USER" ]]; then
    if id -nG "$DESKTOP_USER" | tr ' ' '\n' | grep -qx "$ADMIN_GROUP"; then
        echo "  Benutzer '$DESKTOP_USER' ist bereits in '$ADMIN_GROUP'."
    else
        echo "  Füge '$DESKTOP_USER' zur Gruppe '$ADMIN_GROUP' hinzu ..."
        usermod -aG "$ADMIN_GROUP" "$DESKTOP_USER"
        echo "  Wirksam nach dem nächsten Login von '$DESKTOP_USER'."
    fi
fi

# ── PolicyKit-Regel installieren ──────────────────────────────────────────
# Atomares Schreiben: erst Temp-Datei, dann rename.
# Verhindert dass polkit bei Unterbrechung eine leere Regel-Datei lädt.

echo "→ Installiere PolicyKit-Regel nach $POLKIT_DEST ..."
RULES_DEST="$POLKIT_DEST/50-fotoserver.rules"
TMP_RULES="$(mktemp "$POLKIT_DEST/50-fotoserver.tmp.XXXXXX")"
TMP_FILES+=("$TMP_RULES")

sed "s|/opt/fotoserver|${INSTALL_DIR}|g" "$DESKTOP_SRC/50-fotoserver.rules" > "$TMP_RULES"
chmod 644 "$TMP_RULES"
chown root:root "$TMP_RULES"
mv -f "$TMP_RULES" "$RULES_DEST"
echo "  $RULES_DEST"

# ── Skript-Verzeichnis absichern ──────────────────────────────────────────
# Die polkit-Regel erlaubt pkexec-Zugriff auf diese Skripte.
# Root-Eigentuemer verhindert, dass ein unprivilegierter Nutzer die Skripte
# austauscht und damit die Rechteeskalation uebernimmt.

echo "→ Sichere Skript-Verzeichnis (root:root) ..."
chown root:root "${INSTALL_DIR}/deploy/scripts"
chmod 755 "${INSTALL_DIR}/deploy/scripts"
for s in fotoserver-start.sh fotoserver-stop.sh fotoserver-restart.sh fotoserver-status.sh; do
    TARGET_SCRIPT="${INSTALL_DIR}/deploy/scripts/${s}"
    if [[ -f "$TARGET_SCRIPT" ]]; then
        chown root:root "$TARGET_SCRIPT"
        chmod 755 "$TARGET_SCRIPT"
        echo "  root:root 755  $TARGET_SCRIPT"
    fi
done

# ── Desktop-Dateien in /usr/share/applications installieren ───────────────

echo "→ Installiere Desktop-Einträge nach $APPLICATIONS_DEST ..."
for f in "${DESKTOP_FILES[@]}"; do
    TMP_DESKTOP="$(mktemp "$APPLICATIONS_DEST/${f%.desktop}.tmp.XXXXXX")"
    TMP_FILES+=("$TMP_DESKTOP")
    sed "s|/opt/fotoserver|${INSTALL_DIR}|g" "$DESKTOP_SRC/$f" > "$TMP_DESKTOP"
    chmod 644 "$TMP_DESKTOP"
    chown root:root "$TMP_DESKTOP"
    mv -f "$TMP_DESKTOP" "$APPLICATIONS_DEST/$f"
    echo "  $APPLICATIONS_DEST/$f"
done

# Desktop-Datenbank aktualisieren (falls update-desktop-database vorhanden)
if command -v update-desktop-database &>/dev/null; then
    echo "→ Aktualisiere Desktop-Datenbank ..."
    update-desktop-database "$APPLICATIONS_DEST" 2>/dev/null || true
fi

# ── Optional: Desktop-Shortcuts für Benutzer ──────────────────────────────

if [[ -n "$DESKTOP_USER" ]]; then
    USER_HOME="$(getent passwd "$DESKTOP_USER" | cut -d: -f6)"

    # Home-Verzeichnis validieren: muss unter /home liegen
    if [[ ! "$USER_HOME" =~ ^/home/[a-zA-Z0-9._-]+$ ]]; then
        echo "  Warnung: Unerwartetes Home-Verzeichnis '$USER_HOME' — Desktop-Shortcuts übersprungen." >&2
    else
        USER_DESKTOP="$USER_HOME/Desktop"
        if [[ -d "$USER_DESKTOP" ]]; then
            echo "→ Kopiere Shortcuts auf Desktop von '$DESKTOP_USER' ..."
            for f in "${DESKTOP_FILES[@]}"; do
                cp "$APPLICATIONS_DEST/$f" "$USER_DESKTOP/$f"
                # Datei gehört dem Desktop-Nutzer; chmod 755 nötig damit
                # XFCE/GNOME die Datei als ausführbaren Launcher akzeptiert
                chown "${DESKTOP_USER}:${DESKTOP_USER}" "$USER_DESKTOP/$f"
                chmod 755 "$USER_DESKTOP/$f"
                echo "  $USER_DESKTOP/$f"
            done
        else
            echo "  Kein Desktop-Verzeichnis gefunden für '$DESKTOP_USER' ($USER_DESKTOP)."
            echo "  Shortcuts nur im Anwendungsmenü verfügbar."
        fi
    fi
fi

# ── Fertig ─────────────────────────────────────────────────────────────────

echo ""
echo "Desktop-Shortcuts installiert."
echo ""
echo "  PolicyKit-Regel: $RULES_DEST"
echo "  Admin-Gruppe:    $ADMIN_GROUP"
echo ""

if [[ -z "$DESKTOP_USER" ]]; then
    echo "Benutzer zur Admin-Gruppe hinzufügen (damit pkexec kein Passwort fragt):"
    echo "  sudo usermod -aG $ADMIN_GROUP <benutzername>"
    echo "  Wirksam nach dem nächsten Login."
    echo ""
fi

echo "Shortcuts im Anwendungsmenü: System → Fotoserver *"
echo ""
echo "Zum manuellen Test:"
echo "  pkexec ${INSTALL_DIR}/deploy/scripts/fotoserver-start.sh"
