#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
EXPORT_SCRIPT="${SCRIPT_DIR}/export_to_web.sh"

log() {
  printf '[itch-package] %s\n' "$*"
}

fail() {
  printf '[itch-package][ERROR] %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || fail "No se encontro el comando requerido: ${cmd}"
}

to_abs_path() {
  local path_value="$1"
  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
    return
  fi
  printf '%s\n' "${PROJECT_ROOT}/${path_value#./}"
}

print_usage() {
  cat <<'USAGE'
Uso:
  ./scripts/utils/export_and_package_itch_web.sh

Variables de entorno opcionales:
  EXPORT_MODE         release o debug (default: release)
  EXPORT_PRESET       preset Godot Web (default: autodetect)
  WEB_EXPORT_PATH     ruta de salida HTML web (default: Builds/Web/index.html)
  ITCH_OUT_DIR        directorio de salida del paquete Itch (default: Builds/Itch/web)
  ITCH_ZIP_NAME       nombre del zip final (default: terminal-capitalism-web-itch.zip)

Resultado:
  - Build exportado en Builds/Web
  - Carpeta lista para butler en Builds/Itch/web/package
  - ZIP listo para subir manualmente en Builds/Itch/web/<ITCH_ZIP_NAME>
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

need_cmd find
need_cmd zip
[[ -x "${EXPORT_SCRIPT}" ]] || fail "No existe o no es ejecutable: ${EXPORT_SCRIPT}"

EXPORT_MODE="${EXPORT_MODE:-release}"
WEB_EXPORT_PATH="${WEB_EXPORT_PATH:-Builds/Web/index.html}"
ITCH_OUT_DIR="${ITCH_OUT_DIR:-Builds/Itch/web}"
ITCH_ZIP_NAME="${ITCH_ZIP_NAME:-terminal-capitalism-web-itch.zip}"

WEB_EXPORT_PATH_ABS="$(to_abs_path "${WEB_EXPORT_PATH}")"
WEB_EXPORT_DIR_ABS="$(dirname "${WEB_EXPORT_PATH_ABS}")"
ITCH_OUT_DIR_ABS="$(to_abs_path "${ITCH_OUT_DIR}")"
ITCH_PACKAGE_DIR_ABS="${ITCH_OUT_DIR_ABS}/package"
ITCH_ZIP_PATH_ABS="${ITCH_OUT_DIR_ABS}/${ITCH_ZIP_NAME}"

log "Exportando Web en modo ${EXPORT_MODE}..."
(
  cd "${PROJECT_ROOT}"
  EXPORT_MODE="${EXPORT_MODE}" \
  EXPORT_PRESET="${EXPORT_PRESET:-}" \
  WEB_EXPORT_PATH="${WEB_EXPORT_PATH}" \
  WEB_EXPORT_CLEAN="${WEB_EXPORT_CLEAN:-1}" \
  "${EXPORT_SCRIPT}"
)

[[ -f "${WEB_EXPORT_PATH_ABS}" ]] || fail "No existe el HTML exportado: ${WEB_EXPORT_PATH_ABS}"
[[ -d "${WEB_EXPORT_DIR_ABS}" ]] || fail "No existe el directorio exportado: ${WEB_EXPORT_DIR_ABS}"

log "Preparando carpeta para Itch.io..."
rm -rf -- "${ITCH_PACKAGE_DIR_ABS}"
mkdir -p -- "${ITCH_PACKAGE_DIR_ABS}"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude '*.import' "${WEB_EXPORT_DIR_ABS}/" "${ITCH_PACKAGE_DIR_ABS}/"
else
  cp -a "${WEB_EXPORT_DIR_ABS}/." "${ITCH_PACKAGE_DIR_ABS}/"
  find "${ITCH_PACKAGE_DIR_ABS}" -name '*.import' -type f -delete
fi

[[ -f "${ITCH_PACKAGE_DIR_ABS}/index.html" ]] || fail "El paquete Itch no contiene index.html en la raiz."

log "Generando ZIP para subida manual..."
mkdir -p -- "${ITCH_OUT_DIR_ABS}"
rm -f -- "${ITCH_ZIP_PATH_ABS}"
(
  cd "${ITCH_PACKAGE_DIR_ABS}"
  zip -qr "${ITCH_ZIP_PATH_ABS}" .
)

ZIP_SIZE_BYTES="$(wc -c < "${ITCH_ZIP_PATH_ABS}")"
log "Paquete listo."
log "Carpeta butler: ${ITCH_PACKAGE_DIR_ABS}"
log "ZIP manual: ${ITCH_ZIP_PATH_ABS} (${ZIP_SIZE_BYTES} bytes)"

cat <<EOF_SUMMARY

Siguiente paso (web de itch.io):
1) Ve a tu proyecto en itch.io.
2) Sube el archivo ZIP:
   ${ITCH_ZIP_PATH_ABS}
3) Marca el upload como "This file will be played in the browser".

Siguiente paso (butler):
- Ejecuta:
  ./scripts/utils/upload_itch_web.sh <usuario/juego> web
EOF_SUMMARY
