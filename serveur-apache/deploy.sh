#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${1:-${SCRIPT_DIR}/a.html}"
DEST_DIR="/var/www/html"
DEST_FILE="${DEST_DIR}/a.html"
LANDING_FILE="${SCRIPT_DIR}/index.html"
LANDING_DEST="${DEST_DIR}/index.html"
STYLE_FILE="${SCRIPT_DIR}/style.css"
STYLE_DEST="${DEST_DIR}/style.css"

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Erreur: fichier HTML introuvable: $SOURCE_FILE" >&2
    exit 1
fi

run_privileged() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "Erreur: les privileges administrateur sont requis pour deployer dans ${DEST_DIR}" >&2
        exit 1
    fi
}

run_privileged install -d -m 0755 "$DEST_DIR"
run_privileged install -m 0644 "$SOURCE_FILE" "$DEST_FILE"
if [[ -f "$LANDING_FILE" ]]; then
    run_privileged install -m 0644 "$LANDING_FILE" "$LANDING_DEST"
fi
if [[ -f "$STYLE_FILE" ]]; then
    run_privileged install -m 0644 "$STYLE_FILE" "$STYLE_DEST"
fi

echo "Deploiement termine: $DEST_FILE, $LANDING_DEST, $STYLE_DEST"