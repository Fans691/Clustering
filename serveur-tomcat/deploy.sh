#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${1:-${SCRIPT_DIR}/a.html}"
DEST_DIR="/opt/tomcat/webapps/ROOT"
DEST_FILE="${DEST_DIR}/a.html"

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

echo "Deploiement termine: $DEST_FILE"
