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

to_powershell_path() {
  local path_value="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "${path_value}"
  else
    printf '%s\n' "${path_value}"
  fi
}

create_zip_archive() {
  local source_dir="$1"
  local destination_zip="$2"

  if command -v zip >/dev/null 2>&1; then
    (
      cd "${source_dir}"
      zip -qr "${destination_zip}" .
    )
    return
  fi

  if command -v powershell.exe >/dev/null 2>&1; then
    local source_dir_ps
    local destination_zip_ps
    source_dir_ps="$(to_powershell_path "${source_dir}")"
    destination_zip_ps="$(to_powershell_path "${destination_zip}")"

    SOURCE_DIR_PS="${source_dir_ps}" DEST_ZIP_PS="${destination_zip_ps}" \
      powershell.exe -NoProfile -Command \
      "\$src=\$env:SOURCE_DIR_PS; \$dst=\$env:DEST_ZIP_PS; if (Test-Path \$dst) { Remove-Item -LiteralPath \$dst -Force }; Compress-Archive -Path (Join-Path \$src '*') -DestinationPath \$dst -CompressionLevel Optimal"
    return
  fi

  fail "No se encontro 'zip' ni 'powershell.exe' para generar el archivo ZIP."
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
  SKIP_EXPORT         si vale 1, no ejecuta export_to_web y empaqueta salida existente (default: 0)
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
[[ -x "${EXPORT_SCRIPT}" ]] || fail "No existe o no es ejecutable: ${EXPORT_SCRIPT}"

EXPORT_MODE="${EXPORT_MODE:-release}"
WEB_EXPORT_PATH="${WEB_EXPORT_PATH:-Builds/Web/index.html}"
ITCH_OUT_DIR="${ITCH_OUT_DIR:-Builds/Itch/web}"
ITCH_ZIP_NAME="${ITCH_ZIP_NAME:-terminal-capitalism-web-itch.zip}"
SKIP_EXPORT="${SKIP_EXPORT:-0}"

case "${SKIP_EXPORT}" in
  0|1) ;;
  *) fail "SKIP_EXPORT invalido: ${SKIP_EXPORT}. Valores permitidos: 0, 1." ;;
esac

WEB_EXPORT_PATH_ABS="$(to_abs_path "${WEB_EXPORT_PATH}")"
WEB_EXPORT_DIR_ABS="$(dirname "${WEB_EXPORT_PATH_ABS}")"
ITCH_OUT_DIR_ABS="$(to_abs_path "${ITCH_OUT_DIR}")"
ITCH_PACKAGE_DIR_ABS="${ITCH_OUT_DIR_ABS}/package"
ITCH_ZIP_PATH_ABS="${ITCH_OUT_DIR_ABS}/${ITCH_ZIP_NAME}"

if [[ "${SKIP_EXPORT}" == "1" ]]; then
  log "SKIP_EXPORT=1, se omite export_to_web y se empaqueta salida existente."
else
  log "Exportando Web en modo ${EXPORT_MODE}..."
  (
    cd "${PROJECT_ROOT}"
    EXPORT_MODE="${EXPORT_MODE}" \
    EXPORT_PRESET="${EXPORT_PRESET:-}" \
    WEB_EXPORT_PATH="${WEB_EXPORT_PATH}" \
    WEB_EXPORT_CLEAN="${WEB_EXPORT_CLEAN:-1}" \
    "${EXPORT_SCRIPT}"
  )
fi

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
create_zip_archive "${ITCH_PACKAGE_DIR_ABS}" "${ITCH_ZIP_PATH_ABS}"

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
