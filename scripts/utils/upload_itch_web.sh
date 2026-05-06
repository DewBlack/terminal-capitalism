#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
PACKAGE_SCRIPT="${SCRIPT_DIR}/export_and_package_itch_web.sh"

log() {
  printf '[itch-upload] %s\n' "$*"
}

fail() {
  printf '[itch-upload][ERROR] %s\n' "$*" >&2
  exit 1
}

print_usage() {
  cat <<'USAGE'
Uso:
  ./scripts/utils/upload_itch_web.sh <usuario/juego> [canal]

Ejemplo:
  ./scripts/utils/upload_itch_web.sh miusuario/terminal-capitalism web

Variables opcionales:
  ITCH_PACKAGE_DIR   carpeta local a subir (default: Builds/Itch/web/package)
  ITCH_VERSION       version visible en itch (ej: 0.4.1)
  SKIP_BUILD         si vale 1, no recompila ni reempaqueta antes de subir
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

[[ $# -ge 1 ]] || fail "Falta el destino remoto <usuario/juego>."

REMOTE_GAME="$1"
CHANNEL="${2:-web}"
REMOTE_TARGET="${REMOTE_GAME}:${CHANNEL}"
ITCH_PACKAGE_DIR="${ITCH_PACKAGE_DIR:-Builds/Itch/web/package}"
ITCH_PACKAGE_DIR_ABS="${PROJECT_ROOT}/${ITCH_PACKAGE_DIR#./}"

command -v butler >/dev/null 2>&1 || fail "butler no esta instalado. Instala butler y ejecuta de nuevo."

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  log "Construyendo y empaquetando antes de subir..."
  (
    cd "${PROJECT_ROOT}"
    "${PACKAGE_SCRIPT}"
  )
fi

[[ -d "${ITCH_PACKAGE_DIR_ABS}" ]] || fail "No existe la carpeta a subir: ${ITCH_PACKAGE_DIR_ABS}"
[[ -f "${ITCH_PACKAGE_DIR_ABS}/index.html" ]] || fail "Falta index.html en la raiz del paquete: ${ITCH_PACKAGE_DIR_ABS}"

log "Subiendo a itch.io -> ${REMOTE_TARGET}"
if [[ -n "${ITCH_VERSION:-}" ]]; then
  butler push "${ITCH_PACKAGE_DIR_ABS}" "${REMOTE_TARGET}" --userversion "${ITCH_VERSION}" --if-changed
else
  butler push "${ITCH_PACKAGE_DIR_ABS}" "${REMOTE_TARGET}" --if-changed
fi

log "Subida completada."
