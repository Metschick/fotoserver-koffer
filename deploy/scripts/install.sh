#!/usr/bin/env bash
# Fotoserver-Koffer – vollständige Erstinstallation auf Raspberry Pi 5 / Kali Linux.
# Idempotent: kann mehrfach ausgeführt werden (überschreibt keine .env).
#
# VERWENDUNG:
#   sudo deploy/scripts/install.sh --source /pfad/zum/repo
#   sudo deploy/scripts/install.sh --version 1.0.0
#   sudo deploy/scripts/install.sh --source . --desktop pi
#
# OPTIONEN:
#   --source DIR    Code aus lokalem Verzeichnis DIR installieren
#   --version VER   Code + Frontend von GitHub Release vVER laden (erfordert curl + git)
#   --desktop USER  Desktop-Shortcuts zusätzlich für USER installieren
#   --no-apt        apt-Installation überspringen (Pakete bereits vorhanden)
#   --help          Diese Hilfe anzeigen
#
# UMGEBUNGSVARIABLEN:
#   FOTOSERVER_INSTALL_DIR=/opt/fotoserver   Installationspfad (Standard)
#   FOTOSERVER_GITHUB_REPO=Metschick/fotoserver-koffer  (Standard)
set -euo pipefail

# ── Temp-Datei-Cleanup (akkumulierend, kein trap-Reset) ────────────────────
_CLEANUP_TMPS=()
_cleanup() { rm -rf "${_CLEANUP_TMPS[@]}" 2>/dev/null || true; }
trap _cleanup EXIT

# ── Konstanten ─────────────────────────────────────────────────────────────
GITHUB_REPO="${FOTOSERVER_GITHUB_REPO:-Metschick/fotoserver-koffer}"
if [[ ! "$GITHUB_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    echo "Fehler: Ungültiges FOTOSERVER_GITHUB_REPO: $GITHUB_REPO" >&2
    echo "  Erwartet: OWNER/REPO (z.B. Metschick/fotoserver-koffer)" >&2
    exit 1
fi
GITHUB_BASE="https://github.com/${GITHUB_REPO}"

APT_PACKAGES=(
    python3 python3-venv python3-pip
    nginx
    ffmpeg
    libmagic1
    git
    curl
    rsync
    hostapd
    dnsmasq
    iproute2
)

# ── Argument-Parsing ───────────────────────────────────────────────────────
SOURCE_DIR=""
VERSION=""
DESKTOP_USER=""
SETUP_HOTSPOT=false
NO_APT=false

usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)   SOURCE_DIR="${2:-}"; shift 2 ;;
        --version)  VERSION="${2:-}";    shift 2 ;;
        --desktop)  DESKTOP_USER="${2:-}"; shift 2 ;;
        --hotspot)  SETUP_HOTSPOT=true;  shift   ;;
        --no-apt)   NO_APT=true;         shift   ;;
        --help|-h)  usage ;;
        *) echo "Unbekannte Option: $1" >&2; echo "  install.sh --help" >&2; exit 1 ;;
    esac
done

if [[ -z "$SOURCE_DIR" && -z "$VERSION" ]]; then
    echo "Fehler: --source DIR oder --version VER erforderlich." >&2
    echo "  install.sh --help" >&2
    exit 1
fi
if [[ -n "$SOURCE_DIR" && -n "$VERSION" ]]; then
    echo "Fehler: --source und --version schließen sich gegenseitig aus." >&2
    exit 1
fi

# ── Pfad-Validierung: INSTALL_DIR ─────────────────────────────────────────
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
    echo "Fehler: FOTOSERVER_INSTALL_DIR darf nicht unter /home oder /root liegen." >&2
    echo "  Grund: systemd ProtectHome=yes würde den Service blockieren." >&2; exit 1
fi

# ── Pfad-Validierung: SOURCE_DIR ──────────────────────────────────────────
if [[ -n "$SOURCE_DIR" ]]; then
    SOURCE_DIR="$(realpath -m "$SOURCE_DIR")"
    if [[ ! -d "$SOURCE_DIR" ]]; then
        echo "Fehler: Quellverzeichnis nicht gefunden: $SOURCE_DIR" >&2; exit 1
    fi
    if [[ ! -f "$SOURCE_DIR/backend/requirements.txt" ]]; then
        echo "Fehler: $SOURCE_DIR scheint kein Fotoserver-Koffer-Repository zu sein." >&2
        echo "  Erwartet: $SOURCE_DIR/backend/requirements.txt" >&2; exit 1
    fi
fi

# ── Versions-Validierung ──────────────────────────────────────────────────
if [[ -n "$VERSION" ]]; then
    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Fehler: Ungültiges Versionsformat: $VERSION" >&2
        echo "  Erwartet: MAJOR.MINOR.PATCH (z.B. 1.0.0)" >&2; exit 1
    fi
fi

# ── Desktop-User-Validierung ──────────────────────────────────────────────
if [[ -n "$DESKTOP_USER" ]]; then
    if [[ ! "$DESKTOP_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        echo "Fehler: Ungültiger Benutzername: $DESKTOP_USER" >&2; exit 1
    fi
    if ! id "$DESKTOP_USER" &>/dev/null; then
        echo "Fehler: Benutzer '$DESKTOP_USER' existiert nicht." >&2; exit 1
    fi
fi

# ── Root-Check ────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Fehler: Root-Rechte erforderlich." >&2
    echo "  sudo $0 $*" >&2; exit 1
fi

# ── Hilfsfunktionen ───────────────────────────────────────────────────────
PHASE=0
phase() {
    ((PHASE++)) || true
    echo ""
    echo "══════════════════════════════════════════════════"
    printf "  Phase %d: %s\n" "$PHASE" "$1"
    echo "══════════════════════════════════════════════════"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase 1 – System-Pakete
# ══════════════════════════════════════════════════════════════════════════
phase "System-Pakete"

if [[ "$NO_APT" == true ]]; then
    echo "→ apt übersprungen (--no-apt)."
else
    echo "→ Installiere System-Pakete ..."
    apt-get update -qq
    apt-get install -y "${APT_PACKAGES[@]}"
    echo "  Pakete installiert: ${APT_PACKAGES[*]}"
fi

# Mindest-Anforderungen prüfen
for cmd in python3 rsync curl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Fehler: $cmd nicht gefunden. Bitte installieren oder --no-apt entfernen." >&2
        exit 1
    fi
done

# ══════════════════════════════════════════════════════════════════════════
# Phase 2 – Verzeichnisstruktur
# ══════════════════════════════════════════════════════════════════════════
phase "Verzeichnisstruktur"

echo "→ Erstelle Installationsverzeichnis: $INSTALL_DIR ..."
install -d -m 755 "$INSTALL_DIR"

# ══════════════════════════════════════════════════════════════════════════
# Phase 3 – Anwendungscode
# ══════════════════════════════════════════════════════════════════════════
phase "Anwendungscode"

if [[ -n "$SOURCE_DIR" ]]; then
    SRC_RESOLVED="$(realpath "$SOURCE_DIR")"
    DST_RESOLVED="$(realpath "$INSTALL_DIR")"

    if [[ "$SRC_RESOLVED" == "$DST_RESOLVED" ]]; then
        echo "→ Quelle = Ziel ($INSTALL_DIR) — kein Kopieren nötig."
    else
        echo "→ Kopiere Code: $SOURCE_DIR → $INSTALL_DIR ..."
        rsync -a \
            --exclude='.git/' \
            --exclude='**/__pycache__/' \
            --exclude='**/*.pyc' \
            --exclude='backend/venv/' \
            --exclude='frontend/node_modules/' \
            --exclude='frontend/dist/' \
            --exclude='.env' \
            --exclude='uploads/' \
            --exclude='data/' \
            --exclude='*.db' \
            "$SOURCE_DIR/" "$INSTALL_DIR/"
        echo "  Fertig."
    fi

elif [[ -n "$VERSION" ]]; then
    echo "→ Lade Quellcode v${VERSION} von GitHub ..."
    TMP_SRC="$(mktemp -d /tmp/fotoserver-src-XXXXXX)"
    TMP_SRC_TAR="$(mktemp /tmp/fotoserver-src-XXXXXX.tar.gz)"
    _CLEANUP_TMPS+=("$TMP_SRC" "$TMP_SRC_TAR")
    APP_URL="${GITHUB_BASE}/archive/refs/tags/v${VERSION}.tar.gz"
    if ! curl -fsSL --proto '=https' --tlsv1.2 --max-redirs 3 \
            -o "$TMP_SRC_TAR" "$APP_URL"; then
        echo "Fehler: Download fehlgeschlagen: $APP_URL" >&2; exit 1
    fi
    if ! tar -xz -C "$TMP_SRC" --strip-components=1 -f "$TMP_SRC_TAR"; then
        echo "Fehler: Entpacken fehlgeschlagen." >&2; exit 1
    fi
    rsync -a \
        --exclude='.git/' \
        --exclude='**/__pycache__/' \
        --exclude='**/*.pyc' \
        --exclude='backend/venv/' \
        --exclude='frontend/node_modules/' \
        --exclude='frontend/dist/' \
        --exclude='.env' \
        --exclude='uploads/' \
        --exclude='data/' \
        --exclude='*.db' \
        "$TMP_SRC/" "$INSTALL_DIR/"
    echo "  Quellcode v${VERSION} installiert."
fi

# ══════════════════════════════════════════════════════════════════════════
# Phase 4 – Python venv + Abhängigkeiten
# ══════════════════════════════════════════════════════════════════════════
phase "Python venv + Abhängigkeiten"

VENV="$INSTALL_DIR/backend/venv"
if [[ ! -x "$VENV/bin/python" ]]; then
    echo "→ Erstelle Python-venv: $VENV ..."
    python3 -m venv "$VENV"
else
    echo "→ venv bereits vorhanden: $VENV"
fi

echo "→ Installiere Python-Abhängigkeiten ..."
"$VENV/bin/pip" install --upgrade pip --quiet
"$VENV/bin/pip" install -r "$INSTALL_DIR/backend/requirements.txt" --quiet
echo "  requirements.txt installiert."

# ══════════════════════════════════════════════════════════════════════════
# Phase 5 – Frontend (dist/)
# ══════════════════════════════════════════════════════════════════════════
phase "Frontend dist"

if [[ -n "$SOURCE_DIR" ]]; then
    SRC_DIST="$SOURCE_DIR/frontend/dist"
    if [[ -d "$SRC_DIST" ]]; then
        echo "→ Kopiere frontend/dist/ ..."
        rsync -a "$SRC_DIST/" "$INSTALL_DIR/frontend/dist/"
        echo "  Fertig."
    else
        echo "  Warnung: $SRC_DIST nicht gefunden." >&2
        echo "  Frontend bauen (auf Entwicklungs-PC):" >&2
        echo "    cd frontend && npm ci && npm run build" >&2
        echo "  Dann install.sh erneut mit --source ausführen." >&2
    fi

elif [[ -n "$VERSION" ]]; then
    echo "→ Lade Frontend-Release v${VERSION} ..."
    DIST_URL="${GITHUB_BASE}/releases/download/v${VERSION}/frontend-dist.tar.gz"
    SHA_URL="${DIST_URL}.sha256"

    TMP_DIST="$(mktemp /tmp/frontend-dist-XXXXXX.tar.gz)"
    TMP_SHA="$(mktemp /tmp/frontend-dist-XXXXXX.sha256)"
    TMP_DIST_DIR="$(mktemp -d /tmp/fotoserver-dist-XXXXXX)"
    _CLEANUP_TMPS+=("$TMP_DIST" "$TMP_SHA" "$TMP_DIST_DIR")

    if ! curl -fsSL --proto '=https' --tlsv1.2 --max-redirs 3 -o "$TMP_SHA" "$SHA_URL"; then
        echo "Fehler: SHA256-Datei nicht abrufbar: $SHA_URL" >&2; exit 1
    fi
    if ! curl -fsSL --proto '=https' --tlsv1.2 --max-redirs 3 -o "$TMP_DIST" "$DIST_URL"; then
        echo "Fehler: Frontend-Archiv nicht abrufbar: $DIST_URL" >&2; exit 1
    fi

    # SHA256-Prüfsumme validieren
    echo "→ Prüfe SHA256-Prüfsumme ..."
    EXPECTED_SHA="$(awk '{print $1}' "$TMP_SHA")"
    ACTUAL_SHA="$(sha256sum "$TMP_DIST" | awk '{print $1}')"
    if [[ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]]; then
        echo "Fehler: SHA256-Prüfsumme stimmt nicht überein!" >&2
        echo "  Erwartet: $EXPECTED_SHA" >&2
        echo "  Erhalten: $ACTUAL_SHA" >&2; exit 1
    fi
    echo "  SHA256 OK."

    tar -xz -C "$TMP_DIST_DIR" -f "$TMP_DIST"
    rsync -a "$TMP_DIST_DIR/" "$INSTALL_DIR/frontend/dist/"
    echo "  Frontend-dist v${VERSION} installiert."
fi

# ══════════════════════════════════════════════════════════════════════════
# Phase 6 – Konfiguration (.env)
# ══════════════════════════════════════════════════════════════════════════
phase "Konfiguration (.env)"

ENV_FILE="$INSTALL_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
    echo "→ .env bereits vorhanden — nicht überschrieben."
else
    echo "→ Erstelle .env aus .env.example ..."
    cp "$INSTALL_DIR/.env.example" "$ENV_FILE"

    # Zufälligen SECRET_KEY einsetzen (nur [0-9a-f], sicher für sed)
    NEW_KEY="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
    if grep -q 'SECRET_KEY=CHANGE_ME' "$ENV_FILE"; then
        sed -i "s|SECRET_KEY=CHANGE_ME|SECRET_KEY=${NEW_KEY}|" "$ENV_FILE"
    else
        echo "  Warnung: Platzhalter SECRET_KEY=CHANGE_ME nicht in .env.example gefunden." >&2
        echo "  SECRET_KEY wurde NICHT automatisch gesetzt — bitte manuell in .env eintragen." >&2
    fi

    chmod 600 "$ENV_FILE"
    chown root:root "$ENV_FILE"
    echo "  .env angelegt mit zufälligem SECRET_KEY."
    echo "  WICHTIG: USER_PASSWORD_HASH und ADMIN_PASSWORD_HASH in .env setzen!"
fi

# ══════════════════════════════════════════════════════════════════════════
# Phase 7 – Dateisystem-Berechtigungen
# ══════════════════════════════════════════════════════════════════════════
# Bewusst KEINE rekursive chown/chmod über $INSTALL_DIR: dieses Projekt lässt
# /opt/fotoserver zugleich Git-Arbeitsverzeichnis und Produktivinstallation sein
# (Entwickler committet/pusht direkt hier). Ein rekursives root:root würde den
# Betreiber aus dem eigenen Repo aussperren. Schutz vor einem kompromittierten
# fotoserver-Serviceprozess liefert bereits ProtectSystem=strict + ReadWritePaths
# in fotoserver-api.service (Code ist für den Service ohnehin nie beschreibbar,
# unabhängig von Unix-Ownership) — daher nur die tatsächlich sicherheitsrelevanten
# Pfade gezielt härten: die Secrets-Datei und die per sudo/pkexec aufgerufenen
# Steuerskripte (deren root-Ownership fotoserver-start.sh & Co. explizit prüfen,
# siehe Schritt 11/12 — sonst könnte ein unprivilegierter Nutzer sie austauschen).
phase "Dateisystem-Berechtigungen"

if [[ -f "$INSTALL_DIR/.env" ]]; then
    chown root:root "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"
    echo "  $INSTALL_DIR/.env (chmod 600, root:root)"
fi
# uploads/ und data/ erhalten ihre fotoserver-Ownership durch setup-systemd.sh.
chown root:root "$INSTALL_DIR/deploy/scripts"
find "$INSTALL_DIR/deploy/scripts" -name "*.sh" -exec chown root:root {} + -exec chmod 755 {} +
echo "  $INSTALL_DIR/deploy/scripts (root:root, 755)"
echo "  Fertig."

# ══════════════════════════════════════════════════════════════════════════
# Phase 8 – systemd-Setup
# ══════════════════════════════════════════════════════════════════════════
phase "systemd-Setup"

FOTOSERVER_INSTALL_DIR="$INSTALL_DIR" \
    "$INSTALL_DIR/deploy/scripts/setup-systemd.sh"

# ══════════════════════════════════════════════════════════════════════════
# Phase 9 – Nginx-Setup
# ══════════════════════════════════════════════════════════════════════════
phase "Nginx-Setup"

FOTOSERVER_INSTALL_DIR="$INSTALL_DIR" \
    "$INSTALL_DIR/deploy/scripts/setup-nginx.sh"

# ══════════════════════════════════════════════════════════════════════════
# Phase 10 – Hotspot-Setup (optional, --hotspot)
# ══════════════════════════════════════════════════════════════════════════
if [[ "$SETUP_HOTSPOT" == true ]]; then
    phase "Hotspot-Setup"
    FOTOSERVER_INSTALL_DIR="$INSTALL_DIR" \
    FOTOSERVER_GITHUB_REPO="$GITHUB_REPO" \
        "$INSTALL_DIR/deploy/scripts/setup-hotspot.sh"
fi

# ══════════════════════════════════════════════════════════════════════════
# Phase 11 – Desktop-Shortcuts (optional)
# ══════════════════════════════════════════════════════════════════════════
if [[ -n "$DESKTOP_USER" ]]; then
    phase "Desktop-Shortcuts"
    FOTOSERVER_INSTALL_DIR="$INSTALL_DIR" \
        "$INSTALL_DIR/deploy/scripts/setup-desktop.sh" "$DESKTOP_USER"
fi

# ══════════════════════════════════════════════════════════════════════════
# Zusammenfassung
# ══════════════════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════"
echo "  Installation abgeschlossen"
echo "══════════════════════════════════════════════════"
echo ""
echo "  Installationsverzeichnis: $INSTALL_DIR"
if [[ -n "$VERSION" ]]; then
    echo "  Version:                  v${VERSION}"
fi
echo ""
echo "Nächste Schritte:"
echo ""
echo "  1. .env anpassen (Passwörter als bcrypt-Hash setzen):"
echo "       nano $INSTALL_DIR/.env"
echo ""
echo "     USER_PASSWORD_HASH generieren:"
echo "       python3 -c \"import bcrypt; print(bcrypt.hashpw(b'passwort', bcrypt.gensalt()).decode())\""
echo ""
echo "  2. Fotoserver starten:"
echo "       sudo $INSTALL_DIR/deploy/scripts/fotoserver-start.sh"
echo ""
echo "  3. Status prüfen:"
echo "       $INSTALL_DIR/deploy/scripts/fotoserver-status.sh"
echo ""
echo "  4. Logs:"
echo "       sudo journalctl -u fotoserver-api -f"
echo ""
if [[ -z "$DESKTOP_USER" && -n "$(command -v pkexec 2>/dev/null)" ]]; then
    echo "  Optional: Desktop-Shortcuts installieren:"
    echo "       sudo $INSTALL_DIR/deploy/scripts/setup-desktop.sh <benutzername>"
    echo ""
fi
