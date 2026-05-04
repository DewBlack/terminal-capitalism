#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
TMP_ROOT="${PROJECT_ROOT}/.tmp/web_minio_export"

log() {
  printf '[web-minio] %s\n' "$*"
}

fail() {
  printf '[web-minio][ERROR] %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || fail "No se encontro el comando requerido: ${cmd}"
}

validate_boolean_flag() {
  local value="$1"
  local label="$2"

  case "${value}" in
    0|1) ;;
    *)
      fail "${label} debe ser 0 o 1. Valor recibido: ${value}"
      ;;
  esac
}

to_abs_path() {
  local path_value="$1"

  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
    return
  fi

  printf '%s\n' "${PROJECT_ROOT}/${path_value#./}"
}

normalize_minio_endpoint() {
  local endpoint="$1"
  local secure_flag="$2"
  local scheme="http"

  if [[ "${endpoint}" == http://* || "${endpoint}" == https://* ]]; then
    printf '%s\n' "${endpoint}"
    return
  fi

  if [[ "${secure_flag}" == "1" ]]; then
    scheme="https"
  fi

  printf '%s://%s\n' "${scheme}" "${endpoint}"
}

compress_brotli_assets_in_dir() {
  local build_dir="$1"
  local asset_path=""
  local asset_name=""
  local compressed_any=0

  shopt -s nullglob
  for asset_path in "${build_dir}"/*.js "${build_dir}"/*.wasm "${build_dir}"/*.pck; do
    [[ -f "${asset_path}" ]] || continue

    asset_name="$(basename "${asset_path}")"
    brotli --best --force --keep "${asset_path}"
    log "Brotli generado: ${asset_name}.br"
    compressed_any=1
  done
  shopt -u nullglob

  if [[ "${compressed_any}" != "1" ]]; then
    fail "No se encontraron assets .js/.wasm/.pck para comprimir en ${build_dir}"
  fi
}

print_usage() {
  cat <<'EOF'
Uso:
  MINIO_ENDPOINT=minio.midominio.com:9000 \
  MINIO_ACCESS_KEY=xxxx \
  MINIO_SECRET_KEY=yyyy \
  MINIO_BUCKET=slot-web \
  ./scripts/utils/export_and_deploy_to_minio.sh

Variables de entorno:
  GODOT_BIN             (opcional) Binario Godot CLI. Default: godot4/godot detectado
  EXPORT_MODE           (opcional) release o debug. Default: release
  EXPORT_PRESET         (opcional) Preset Godot Web. Default: primer preset con platform=Web
  WEB_EXPORT_PATH       (opcional) Ruta del HTML exportado. Default: Builds/Web/index.html
  WEB_EXPORT_CLEAN      (opcional) Si vale 1, limpia el staging antes de exportar. Default: 1
  WEB_BROTLI_COMPRESS   (opcional) Si vale 1, genera .br para .js/.wasm/.pck antes de subir. Default: 1
  MINIO_ENDPOINT        (opcional) Endpoint MinIO. Acepta host:puerto o URL completa
  MINIO_URL             (opcional) Alias de MINIO_ENDPOINT
  MINIO_ACCESS_KEY      (obligatoria) Access key de MinIO
  MINIO_SECRET_KEY      (obligatoria) Secret key de MinIO
  MINIO_BUCKET          (obligatoria) Bucket destino
  MINIO_PREFIX          (opcional) Prefijo/carpeta remota dentro del bucket
  MINIO_ALIAS_NAME      (opcional) Alias temporal de mc. Default: local
  MINIO_ALIAS           (opcional) Alias de MINIO_ALIAS_NAME
  MINIO_SECURE          (opcional) Si vale 1 usa https cuando el endpoint no trae esquema. Default: 1
  MINIO_INSECURE        (opcional) Si vale 1, pasa --insecure a mc. Default: 0
  MINIO_PATH_LOOKUP     (opcional) auto, on o off. Default: auto
  MINIO_CREATE_BUCKET   (opcional) Si vale 1, crea el bucket si no existe. Default: 1
  MINIO_PRUNE_REMOTE    (opcional) Si vale 1, elimina objetos remotos que no esten en el export. Default: 0
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

EXPORT_MODE="${EXPORT_MODE:-debug}"
WEB_EXPORT_PATH="${WEB_EXPORT_PATH:-Builds/Web/index.html}"
WEB_EXPORT_CLEAN="${WEB_EXPORT_CLEAN:-1}"
WEB_BROTLI_COMPRESS="${WEB_BROTLI_COMPRESS:-1}"

MINIO_SECURE="${MINIO_SECURE:-1}"
MINIO_INSECURE="${MINIO_INSECURE:-0}"
MINIO_CREATE_BUCKET="${MINIO_CREATE_BUCKET:-1}"
MINIO_PRUNE_REMOTE="${MINIO_PRUNE_REMOTE:-0}"

validate_boolean_flag "${WEB_EXPORT_CLEAN}" "WEB_EXPORT_CLEAN"
validate_boolean_flag "${WEB_BROTLI_COMPRESS}" "WEB_BROTLI_COMPRESS"
validate_boolean_flag "${MINIO_SECURE}" "MINIO_SECURE"
validate_boolean_flag "${MINIO_INSECURE}" "MINIO_INSECURE"
validate_boolean_flag "${MINIO_CREATE_BUCKET}" "MINIO_CREATE_BUCKET"
validate_boolean_flag "${MINIO_PRUNE_REMOTE}" "MINIO_PRUNE_REMOTE"

if [[ "${WEB_BROTLI_COMPRESS}" == "1" ]]; then
  need_cmd brotli
fi

log "Generando export Web previo a la subida"
GODOT_BIN="${GODOT_BIN:-}" \
EXPORT_MODE="${EXPORT_MODE}" \
EXPORT_PRESET="${EXPORT_PRESET:-}" \
WEB_EXPORT_PATH="${WEB_EXPORT_PATH}" \
WEB_EXPORT_CLEAN="${WEB_EXPORT_CLEAN}" \
  "${SCRIPT_DIR}/export_to_web.sh"

EXPORT_HTML_ABS="$(to_abs_path "${WEB_EXPORT_PATH}")"
EXPORT_DIR="$(dirname "${EXPORT_HTML_ABS}")"

if [[ "${WEB_BROTLI_COMPRESS}" == "1" ]]; then
  log "Generando assets Brotli en ${EXPORT_DIR}"
  compress_brotli_assets_in_dir "${EXPORT_DIR}"
fi

MINIO_ENDPOINT_VALUE="${MINIO_URL:-${MINIO_ENDPOINT:-}}"
MINIO_ACCESS_KEY_VALUE="${MINIO_ACCESS_KEY:-${MINIO_ROOT_USER:-}}"
MINIO_SECRET_KEY_VALUE="${MINIO_SECRET_KEY:-${MINIO_ROOT_PASSWORD:-}}"
MINIO_BUCKET_VALUE="${MINIO_BUCKET:-}"
MINIO_PREFIX_VALUE="${MINIO_PREFIX:-}"
MINIO_ALIAS_VALUE="${MINIO_ALIAS:-${MINIO_ALIAS_NAME:-local}}"
MINIO_PATH_LOOKUP_VALUE="${MINIO_PATH_LOOKUP:-auto}"

[[ -n "${MINIO_ENDPOINT_VALUE}" ]] || fail "Falta MINIO_ENDPOINT o MINIO_URL."
[[ -n "${MINIO_ACCESS_KEY_VALUE}" ]] || fail "Falta MINIO_ACCESS_KEY o MINIO_ROOT_USER."
[[ -n "${MINIO_SECRET_KEY_VALUE}" ]] || fail "Falta MINIO_SECRET_KEY o MINIO_ROOT_PASSWORD."
[[ -n "${MINIO_BUCKET_VALUE}" ]] || fail "Falta MINIO_BUCKET."

MINIO_URL_RESOLVED="$(normalize_minio_endpoint "${MINIO_ENDPOINT_VALUE}" "${MINIO_SECURE}")"

declare -a UPLOAD_ARGS
UPLOAD_ARGS=(
  --source-dir "${EXPORT_DIR}"
  --bucket "${MINIO_BUCKET_VALUE}"
  --minio-url "${MINIO_URL_RESOLVED}"
  --alias "${MINIO_ALIAS_VALUE}"
  --access-key "${MINIO_ACCESS_KEY_VALUE}"
  --secret-key "${MINIO_SECRET_KEY_VALUE}"
  --path-lookup "${MINIO_PATH_LOOKUP_VALUE}"
)

if [[ -n "${MINIO_PREFIX_VALUE}" ]]; then
  UPLOAD_ARGS+=(--prefix "${MINIO_PREFIX_VALUE}")
fi
if [[ "${MINIO_INSECURE}" == "1" ]]; then
  UPLOAD_ARGS+=(--insecure)
fi
if [[ "${MINIO_CREATE_BUCKET}" != "1" ]]; then
  UPLOAD_ARGS+=(--no-create-bucket)
fi
if [[ "${MINIO_PRUNE_REMOTE}" == "1" ]]; then
  UPLOAD_ARGS+=(--prune-remote)
fi

log "Subiendo export Web desde ${EXPORT_DIR} al bucket ${MINIO_BUCKET_VALUE}"
"${SCRIPT_DIR}/upload-minio-dir.sh" "${UPLOAD_ARGS[@]}"

log "Export y subida completados."
