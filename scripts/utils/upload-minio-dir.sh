#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  scripts/utils/upload-minio-dir.sh --source-dir DIR --bucket BUCKET [opciones]

Opciones:
  --source-dir DIR         Directorio local a subir. Obligatorio.
  --bucket BUCKET          Bucket destino. Obligatorio.
  --prefix PATH            Prefijo/path dentro del bucket. Opcional.
  --minio-url URL          URL de MinIO. Por defecto: MINIO_URL o http://127.0.0.1:9000
  --alias NAME             Alias local para mc. Por defecto: MINIO_ALIAS o local
  --access-key KEY         Access key de MinIO/S3. Opcional si usas variables de entorno.
  --secret-key KEY         Secret key de MinIO/S3. Opcional si usas variables de entorno.
  --path-lookup MODE       Valor para mc alias set --path. Default: MINIO_PATH_LOOKUP o auto.
  --insecure               Pasa --insecure a mc.
  --no-create-bucket       No crea el bucket si no existe.
  --prune-remote           Elimina objetos remotos no presentes localmente.
  -h, --help               Muestra esta ayuda.

Variables de entorno admitidas:
  MINIO_URL
  MINIO_ALIAS
  MINIO_MC_BIN
  MINIO_ACCESS_KEY / MINIO_SECRET_KEY
  MINIO_ROOT_USER / MINIO_ROOT_PASSWORD
  MINIO_PATH_LOOKUP
  MINIO_INSECURE
EOF
}

require_cmd() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Falta el comando requerido: %s\n' "$cmd" >&2
    exit 1
  fi
}

resolve_mc_bin() {
  if [[ -n "${MINIO_MC_BIN:-}" ]]; then
    if command -v "${MINIO_MC_BIN}" >/dev/null 2>&1 || [[ -x "${MINIO_MC_BIN}" ]]; then
      printf '%s\n' "${MINIO_MC_BIN}"
      return
    fi
    printf 'MINIO_MC_BIN no es ejecutable ni existe en PATH: %s\n' "${MINIO_MC_BIN}" >&2
    exit 1
  fi

  require_cmd mc
  printf '%s\n' "mc"
}

trim_slashes() {
  local value=$1
  value=${value#/}
  value=${value%/}
  printf '%s\n' "$value"
}

validate_path_lookup() {
  local value=$1

  case "$value" in
    auto|on|off) ;;
    *)
      printf 'MINIO_PATH_LOOKUP invalido: %s\n' "$value" >&2
      exit 1
      ;;
  esac
}

SOURCE_DIR=
BUCKET=
PREFIX=
MINIO_URL=${MINIO_URL:-http://127.0.0.1:9000}
MINIO_ALIAS=${MINIO_ALIAS:-local}
ACCESS_KEY=${MINIO_ACCESS_KEY:-${MINIO_ROOT_USER:-}}
SECRET_KEY=${MINIO_SECRET_KEY:-${MINIO_ROOT_PASSWORD:-}}
MINIO_PATH_LOOKUP=${MINIO_PATH_LOOKUP:-auto}
MINIO_INSECURE=${MINIO_INSECURE:-1}
CREATE_BUCKET=1
PRUNE_REMOTE=0

while (($# > 0)); do
  case "$1" in
    --source-dir)
      SOURCE_DIR=${2:-}
      shift 2
      ;;
    --bucket)
      BUCKET=${2:-}
      shift 2
      ;;
    --prefix)
      PREFIX=${2:-}
      shift 2
      ;;
    --minio-url)
      MINIO_URL=${2:-}
      shift 2
      ;;
    --alias)
      MINIO_ALIAS=${2:-}
      shift 2
      ;;
    --access-key)
      ACCESS_KEY=${2:-}
      shift 2
      ;;
    --secret-key)
      SECRET_KEY=${2:-}
      shift 2
      ;;
    --path-lookup)
      MINIO_PATH_LOOKUP=${2:-}
      shift 2
      ;;
    --insecure)
      MINIO_INSECURE=1
      shift
      ;;
    --no-create-bucket)
      CREATE_BUCKET=0
      shift
      ;;
    --prune-remote)
      PRUNE_REMOTE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Opcion no reconocida: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SOURCE_DIR" || -z "$BUCKET" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  printf 'El directorio no existe: %s\n' "$SOURCE_DIR" >&2
  exit 1
fi

if [[ -z "$ACCESS_KEY" || -z "$SECRET_KEY" ]]; then
  printf 'Faltan credenciales de MinIO. Usa MINIO_ACCESS_KEY/MINIO_SECRET_KEY o MINIO_ROOT_USER/MINIO_ROOT_PASSWORD.\n' >&2
  exit 1
fi

validate_path_lookup "$MINIO_PATH_LOOKUP"
MC_BIN="$(resolve_mc_bin)"

SOURCE_DIR=$(cd -- "$SOURCE_DIR" && pwd)
BUCKET=$(trim_slashes "$BUCKET")
PREFIX=$(trim_slashes "$PREFIX")

TARGET="${MINIO_ALIAS}/${BUCKET}"
if [[ -n "$PREFIX" ]]; then
  TARGET="${TARGET}/${PREFIX}"
fi

declare -a MC_ARGS
MC_ARGS=()
if [[ "$MINIO_INSECURE" == "1" ]]; then
  MC_ARGS+=(--insecure)
fi

printf 'Configurando alias %s -> %s\n' "$MINIO_ALIAS" "$MINIO_URL"
"${MC_BIN}" "${MC_ARGS[@]}" alias set \
  --api S3v4 \
  --path "$MINIO_PATH_LOOKUP" \
  "$MINIO_ALIAS" \
  "$MINIO_URL" \
  "$ACCESS_KEY" \
  "$SECRET_KEY" >/dev/null

if [[ "$CREATE_BUCKET" == "1" ]]; then
  printf 'Asegurando bucket %s\n' "$BUCKET"
  "${MC_BIN}" "${MC_ARGS[@]}" mb --ignore-existing "${MINIO_ALIAS}/${BUCKET}" >/dev/null
elif ! "${MC_BIN}" "${MC_ARGS[@]}" ls "${MINIO_ALIAS}/${BUCKET}" >/dev/null 2>&1; then
  printf 'El bucket no existe o no es accesible: %s\n' "$BUCKET" >&2
  exit 1
fi

printf 'Subiendo %s a %s\n' "$SOURCE_DIR" "$TARGET"
if [[ "$PRUNE_REMOTE" == "1" ]]; then
  "${MC_BIN}" "${MC_ARGS[@]}" mirror --overwrite --remove --summary "${SOURCE_DIR}" "${TARGET}"
else
  "${MC_BIN}" "${MC_ARGS[@]}" mirror --overwrite --summary "${SOURCE_DIR}" "${TARGET}"
fi

printf 'Subida completada.\n'
