#!/usr/bin/env bash
# Fotoserver-Koffer aktualisieren (Backend-Code + Abhängigkeiten + Neustart).
# Verwendung: sudo deploy/scripts/update.sh
# Optionale Umgebungsvariable:
#   FOTOSERVER_INSTALL_DIR=/opt/fotoserver  (Standard)
set -euo pipefail

GITHUB_REPO="${FOTOSERVER_GITHUB_REPO:-Metschick/fotoserver-koffer}"
if [[ ! "$GITHUB_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    echo "Fehler: Ungültiges FOTOSERVER_GITHUB_REPO: $GITHUB_REPO" >&2
    exit 1
fi

_RAW_INSTALL_DIR="${FOTOSERVER_INSTALL_DIR:-/opt/fotoserver}"
INSTALL_DIR="$(realpath -m "$_RAW_INSTALL_DIR")"

# ── Pfad-Validierung ───────────────────────────────────────────────────────
if [[ ! "$INSTALL_DIR" =~ ^/[a-zA-Z0-9._/-]+$ ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält ungültige Zeichen." >&2; exit 1
fi
if [[ "$INSTALL_DIR" != "$_RAW_INSTALL_DIR" ]]; then
    echo "Fehler: FOTOSERVER_INSTALL_DIR enthält '..' oder ist nicht kanonisch." >&2; exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "Fehler: Root-Rechte erforderlich." >&2
    echo "  sudo $0" >&2; exit 1
fi

if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    echo "Fehler: $INSTALL_DIR ist kein Git-Repository." >&2
    echo "  Für Release-Installationen: deploy/scripts/install.sh --version <VER>" >&2
    exit 1
fi

echo "→ Prüfe Git-Remote-URL ..."
EXPECTED_REMOTE="https://github.com/${GITHUB_REPO}"
ACTUAL_REMOTE="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)"
if [[ "$ACTUAL_REMOTE" != "$EXPECTED_REMOTE" ]]; then
    echo "Fehler: Git-Remote-URL stimmt nicht überein." >&2
    echo "  Erwartet: $EXPECTED_REMOTE" >&2
    echo "  Gefunden: $ACTUAL_REMOTE" >&2
    echo "  Tipp: FOTOSERVER_GITHUB_REPO setzen oder Remote manuell prüfen." >&2
    exit 1
fi

echo "→ Aktualisiere Code (git pull) ..."
git -C "$INSTALL_DIR" pull --ff-only

echo "→ Aktualisiere Python-Abhängigkeiten ..."
"$INSTALL_DIR/backend/venv/bin/pip" install \
    -r "$INSTALL_DIR/backend/requirements.txt" --quiet

echo "→ Aktualisiere systemd-Units (falls geändert) ..."
FOTOSERVER_INSTALL_DIR="$INSTALL_DIR" \
    "$INSTALL_DIR/deploy/scripts/setup-systemd.sh"

echo "→ Starte Fotoserver-API neu ..."
"$INSTALL_DIR/deploy/scripts/fotoserver-restart.sh"

echo ""
echo "Update abgeschlossen."
