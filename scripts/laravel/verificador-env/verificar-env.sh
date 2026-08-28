#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if ! command -v php >/dev/null 2>&1; then
    echo "[ERROR] No se encontro PHP en el PATH." >&2
    exit 2
fi

exec php "$SCRIPT_DIR/verificar-env.php" "$@"
