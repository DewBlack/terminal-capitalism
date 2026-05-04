#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
TMP_ROOT="${PROJECT_ROOT}/.tmp/temp_web_deploy"
SUDO_KEEPALIVE_PID=""
DOCKER_NEEDS_SUDO=0

log() {
  printf '[temp-web] %s\n' "$*"
}

fail() {
  printf '[temp-web][ERROR] %s\n' "$*" >&2
  exit 1
}

cleanup_sudo_keepalive() {
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "${SUDO_KEEPALIVE_PID}" >/dev/null 2>&1 || true
  fi
}

trap cleanup_sudo_keepalive EXIT

reexec_as_original_user_if_needed() {
  if [[ "${EUID}" -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]] && [[ "${SUDO_USER}" != "root" ]]; then
    log "Reejecutando como usuario '${SUDO_USER}' para preservar permisos de archivos."
    exec sudo -u "${SUDO_USER}" \
      --preserve-env=SSL_CERTS_HOST_PATH,SSL_CERT_FILE,SSL_KEY_FILE,WILDCARD_HINT,GODOT_BIN,EXPORT_MODE,EXPORT_PRESET,WEB_EXPORT_PATH,WEB_EXPORT_CLEAN,WEB_BROTLI_COMPRESS,TEMP_TTL_SECONDS,TEMP_WEB_HTTP_PORT,TEMP_WEB_HTTPS_PORT,TEMP_DOMAIN_PREFIX,TEMP_WEB_SHOW_QR,PATH \
      bash "$0" "$@"
  fi
}

require_admin_session() {
  if [[ "${EUID}" -eq 0 ]]; then
    return
  fi

  command -v sudo >/dev/null 2>&1 || fail "Se requieren permisos de administrador y no se encontro sudo."

  if sudo -n true >/dev/null 2>&1; then
    return
  fi

  if [[ ! -t 0 ]]; then
    fail "Se requieren permisos de administrador y no hay TTY para solicitar la clave. Ejecuta 'sudo -v' antes de lanzar el script."
  fi

  log "Solicitando permisos de administrador (sudo)..."
  sudo -v || fail "No se pudo validar la sesion sudo."

  if [[ -z "${SUDO_KEEPALIVE_PID:-}" ]]; then
    (
      while true; do
        sleep 60
        sudo -n true >/dev/null 2>&1 || exit 0
      done
    ) &
    SUDO_KEEPALIVE_PID=$!
  fi
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

declare -a COMPOSE_CMD

resolve_compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
    return
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
    return
  fi
  fail "No se encontro docker compose (plugin o binario docker-compose)."
}

ensure_docker_daemon_access() {
  local docker_info_error=""

  if docker_info_error="$(docker info 2>&1 >/dev/null)"; then
    return
  fi

  if printf '%s\n' "${docker_info_error}" | grep -qi 'permission denied'; then
    require_admin_session
    DOCKER_NEEDS_SUDO=1
    COMPOSE_CMD=(sudo -n "${COMPOSE_CMD[@]}")

    if ! docker_info_error="$(sudo -n docker info 2>&1 >/dev/null)"; then
      fail "No se pudo acceder al daemon de Docker ni con sudo: ${docker_info_error}"
    fi

    log "Sin permisos sobre Docker daemon; se usara sudo para Docker Compose."
    return
  fi

  fail "No se pudo acceder al daemon de Docker: ${docker_info_error}"
}

to_abs_path() {
  local path_value="$1"
  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
    return
  fi
  printf '%s\n' "${PROJECT_ROOT}/${path_value#./}"
}

compress_brotli_assets_in_dir() {
  local build_dir="$1"
  shift

  local asset_name=""
  local asset_path=""

  for asset_name in "$@"; do
    asset_path="${build_dir}/${asset_name}"
    [[ -f "${asset_path}" ]] || fail "No se encontro el asset esperado para Brotli: ${asset_path}"

    brotli --best --force --keep "${asset_path}"
    log "Brotli generado: ${asset_name}.br"
  done
}

detect_default_ipv4() {
  local detected_ip=""

  if command -v ip >/dev/null 2>&1; then
    detected_ip="$(ip -4 route get 8.8.8.8 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}' || true)"
    if [[ -n "${detected_ip}" ]]; then
      printf '%s\n' "${detected_ip}"
      return 0
    fi
  fi

  if command -v hostname >/dev/null 2>&1; then
    detected_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    if [[ -n "${detected_ip}" ]]; then
      printf '%s\n' "${detected_ip}"
      return 0
    fi
  fi

  return 1
}

build_url() {
  local scheme="$1"
  local host="$2"
  local port="$3"
  local default_port="$4"

  if [[ "${port}" == "${default_port}" ]]; then
    printf '%s://%s\n' "${scheme}" "${host}"
    return 0
  fi

  printf '%s://%s:%s\n' "${scheme}" "${host}" "${port}"
}

is_truthy_value() {
  case "${1,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

print_qr_with_python_qrcode() {
  local url="$1"

  command -v python3 >/dev/null 2>&1 || return 2

  python3 - "${url}" <<'PY'
import sys

try:
    import qrcode
except Exception:
    raise SystemExit(2)

url = sys.argv[1]
qr = qrcode.QRCode(border=2)
qr.add_data(url)
qr.make(fit=True)
matrix = qr.get_matrix()

black = "\033[40m  \033[0m"
white = "\033[47m  \033[0m"

for row in matrix:
    sys.stdout.write("".join(black if cell else white for cell in row))
    sys.stdout.write("\n")
PY
}

print_terminal_qr() {
  local url="$1"
  local python_exit=0

  if ! is_truthy_value "${TEMP_WEB_SHOW_QR:-1}"; then
    return 0
  fi

  if [[ ! -t 1 ]]; then
    log "QR omitido porque la salida no es un terminal interactivo."
    return 0
  fi

  log "QR (escanear para abrir ${url}):"
  printf '\n'

  if command -v qrencode >/dev/null 2>&1; then
    if qrencode -t ANSIUTF8 "${url}"; then
      printf '\n'
      return 0
    fi
    log "Fallo al renderizar el QR con qrencode; se intentara fallback Python."
  fi

  if print_qr_with_python_qrcode "${url}"; then
    printf '\n'
    return 0
  else
    python_exit=$?
  fi

  if [[ "${python_exit}" -ne 2 ]]; then
    log "No se pudo renderizar el QR en terminal."
    printf '\n'
    return 0
  fi

  log "QR no disponible: instala 'qrencode' o el modulo Python 'qrcode' para verlo en terminal."
  printf '\n'
}

print_usage() {
  cat <<'EOF'
Uso:
  SSL_CERTS_HOST_PATH=/ruta/certs ./scripts/utils/export_and_deploy_tmp_web.sh

Notas:
  Ejecutar con tu usuario normal (no root). El script pedira sudo para tareas de administrador.
  Si tu usuario no tiene acceso al socket Docker, se usara sudo tambien para Docker Compose.

Variables de entorno:
  SSL_CERTS_HOST_PATH   (obligatoria) Directorio del host con los certificados.
  SSL_CERT_FILE         (opcional)    Nombre del cert dentro de SSL_CERTS_HOST_PATH. Default: fullchain.pem
  SSL_KEY_FILE          (opcional)    Nombre de la key dentro de SSL_CERTS_HOST_PATH. Default: privkey.pem
  WILDCARD_HINT         (opcional)    Wildcard concreto a usar si el cert tiene varios (ej: *.dev.midominio.com)
  GODOT_BIN             (opcional)    Binario Godot CLI.
  EXPORT_MODE           (opcional)    Modo de export: release o debug. Default: debug
  EXPORT_PRESET         (opcional)    Preset de export de Godot. Default: primer preset con platform=Web
  WEB_EXPORT_PATH       (opcional)    Ruta del HTML exportado. Default: Builds/Web/index.html
  WEB_EXPORT_CLEAN      (opcional)    Si vale 1, limpia el staging antes de exportar. Default: 1
  WEB_BROTLI_COMPRESS   (opcional)    Si vale 0, omite la generacion de .br para el deploy temporal. Default: 1
  TEMP_TTL_SECONDS      (opcional)    Vida del docker en segundos. Default: 900 (15 min)
  TEMP_WEB_HTTP_PORT    (opcional)    Puerto local HTTP. Default: auto (aleatorio libre)
  TEMP_WEB_HTTPS_PORT   (opcional)    Puerto local HTTPS. Default: auto (aleatorio libre)
  TEMP_DOMAIN_PREFIX    (opcional)    Prefijo del dominio temporal. Default: hash corto del commit
  TEMP_WEB_SHOW_QR      (opcional)    Mostrar QR HTTPS en terminal si hay generador disponible. Default: 1
  TEMP_SKIP_HOSTS_ENTRY (opcional)    Si vale 1, no modifica /etc/hosts. Default: 0
EOF
}

extract_wildcards_from_san() {
  local cert_file="$1"
  local san_output=""

  san_output="$(openssl x509 -in "${cert_file}" -noout -ext subjectAltName 2>/dev/null || true)"
  printf '%s\n' "${san_output}" \
    | tr ',' '\n' \
    | sed -nE 's/.*DNS:\*\.([A-Za-z0-9.-]+).*/\1/p' \
    | tr '[:upper:]' '[:lower:]' \
    | sort -u
}

extract_wildcard_from_subject() {
  local cert_file="$1"
  local subject_output=""

  subject_output="$(openssl x509 -in "${cert_file}" -noout -subject 2>/dev/null || true)"
  printf '%s\n' "${subject_output}" \
    | sed -nE 's/.*CN[[:space:]]*=[[:space:]]*\*\.([A-Za-z0-9.-]+).*/\1/p' \
    | tr '[:upper:]' '[:lower:]' \
    | head -n 1
}

is_auto_port_value() {
  local value="${1:-}"
  value="${value,,}"
  [[ -z "${value}" || "${value}" == "auto" || "${value}" == "random" || "${value}" == "rand" ]]
}

validate_port_number() {
  local port="$1"
  local label="$2"

  [[ "${port}" =~ ^[0-9]+$ ]] || fail "${label} debe ser un entero valido: ${port}"
  if (( port < 1 || port > 65535 )); then
    fail "${label} fuera de rango valido (1-65535): ${port}"
  fi
}

is_port_free() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    if ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q .; then
      return 1
    fi
    return 0
  fi

  if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
      return 1
    fi
    return 0
  fi

  fail "No se encontro 'ss' ni 'lsof' para comprobar puertos libres."
}

pick_random_free_port() {
  local avoid_port="${1:-}"
  local min_port=20000
  local max_port=60999
  local tries=300
  local span=$(( max_port - min_port + 1 ))
  local i=0
  local rand=0
  local candidate=0

  for (( i = 0; i < tries; i++ )); do
    rand=$(( (RANDOM << 15) | RANDOM ))
    candidate=$(( (rand % span) + min_port ))

    if [[ -n "${avoid_port}" ]] && (( candidate == avoid_port )); then
      continue
    fi

    if is_port_free "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  fail "No se pudo encontrar un puerto libre aleatorio tras ${tries} intentos."
}

resolve_temp_ports() {
  local http_input="$1"
  local https_input="$2"

  if is_auto_port_value "${http_input}"; then
    if is_auto_port_value "${https_input}"; then
      TEMP_WEB_HTTP_PORT="$(pick_random_free_port)"
      TEMP_WEB_HTTPS_PORT="$(pick_random_free_port "${TEMP_WEB_HTTP_PORT}")"
    else
      validate_port_number "${https_input}" "TEMP_WEB_HTTPS_PORT"
      is_port_free "${https_input}" || fail "TEMP_WEB_HTTPS_PORT ya esta en uso: ${https_input}"
      TEMP_WEB_HTTPS_PORT="${https_input}"
      TEMP_WEB_HTTP_PORT="$(pick_random_free_port "${TEMP_WEB_HTTPS_PORT}")"
    fi
  else
    validate_port_number "${http_input}" "TEMP_WEB_HTTP_PORT"
    is_port_free "${http_input}" || fail "TEMP_WEB_HTTP_PORT ya esta en uso: ${http_input}"
    TEMP_WEB_HTTP_PORT="${http_input}"

    if is_auto_port_value "${https_input}"; then
      TEMP_WEB_HTTPS_PORT="$(pick_random_free_port "${TEMP_WEB_HTTP_PORT}")"
    else
      validate_port_number "${https_input}" "TEMP_WEB_HTTPS_PORT"
      [[ "${http_input}" != "${https_input}" ]] || fail "TEMP_WEB_HTTP_PORT y TEMP_WEB_HTTPS_PORT no pueden ser iguales (${http_input})."
      is_port_free "${https_input}" || fail "TEMP_WEB_HTTPS_PORT ya esta en uso: ${https_input}"
      TEMP_WEB_HTTPS_PORT="${https_input}"
    fi
  fi
}

ensure_hosts_entry() {
  local domain="$1"
  local escaped_domain=""
  local new_line="127.0.0.1 ${domain}"

  if is_truthy_value "${TEMP_SKIP_HOSTS_ENTRY:-0}"; then
    log "Omitiendo alta en /etc/hosts para ${domain} (TEMP_SKIP_HOSTS_ENTRY=${TEMP_SKIP_HOSTS_ENTRY})."
    return
  fi

  escaped_domain="$(printf '%s' "${domain}" | sed 's/[][\/.^$*+?{}|()]/\\&/g')"

  if grep -Eq "(^|[[:space:]])${escaped_domain}([[:space:]]|$)" /etc/hosts; then
    log "Entrada ya existente en /etc/hosts para ${domain}"
    return
  fi

  if [[ -w /etc/hosts ]]; then
    printf '\n%s\n' "${new_line}" >> /etc/hosts
    log "Entrada anadida a /etc/hosts: ${new_line}"
    return
  fi

  require_admin_session
  printf '\n%s\n' "${new_line}" | sudo -n tee -a /etc/hosts >/dev/null \
    || fail "No se pudo anadir la entrada a /etc/hosts."
  log "Entrada anadida a /etc/hosts: ${new_line}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

reexec_as_original_user_if_needed "$@"

need_cmd git
need_cmd openssl
need_cmd docker
resolve_compose_cmd
ensure_docker_daemon_access

EXPORT_MODE="${EXPORT_MODE:-debug}"
WEB_EXPORT_PATH="${WEB_EXPORT_PATH:-Builds/Web/index.html}"
WEB_EXPORT_CLEAN="${WEB_EXPORT_CLEAN:-1}"
WEB_BROTLI_COMPRESS="${WEB_BROTLI_COMPRESS:-0}"

SSL_CERTS_HOST_PATH="$HOME/certs" 
SSL_CERT_FILE="${SSL_CERT_FILE:-fullchain.pem}"
SSL_KEY_FILE="${SSL_KEY_FILE:-privkey.pem}"
TEMP_TTL_SECONDS="${TEMP_TTL_SECONDS:-900}"
TEMP_WEB_HTTP_PORT="${TEMP_WEB_HTTP_PORT:-auto}"
TEMP_WEB_HTTPS_PORT="${TEMP_WEB_HTTPS_PORT:-auto}"
TEMP_WEB_SHOW_QR="${TEMP_WEB_SHOW_QR:-1}"
TEMP_SKIP_HOSTS_ENTRY="${TEMP_SKIP_HOSTS_ENTRY:-0}"

validate_boolean_flag "${WEB_EXPORT_CLEAN}" "WEB_EXPORT_CLEAN"
validate_boolean_flag "${WEB_BROTLI_COMPRESS}" "WEB_BROTLI_COMPRESS"

if [[ "${WEB_BROTLI_COMPRESS}" == "1" ]]; then
  need_cmd brotli
fi

[[ "${TEMP_TTL_SECONDS}" =~ ^[0-9]+$ ]] || fail "TEMP_TTL_SECONDS debe ser un entero positivo."
(( TEMP_TTL_SECONDS > 0 )) || fail "TEMP_TTL_SECONDS debe ser mayor que 0."
resolve_temp_ports "${TEMP_WEB_HTTP_PORT}" "${TEMP_WEB_HTTPS_PORT}"
log "Puertos asignados -> HTTP: ${TEMP_WEB_HTTP_PORT}, HTTPS: ${TEMP_WEB_HTTPS_PORT}"

if [[ ! -d "${SSL_CERTS_HOST_PATH}" ]]; then
  fail "SSL_CERTS_HOST_PATH no es un directorio valido: ${SSL_CERTS_HOST_PATH}"
fi

SSL_CERTS_HOST_PATH="$(cd "${SSL_CERTS_HOST_PATH}" && pwd)"
CERT_PATH="${SSL_CERTS_HOST_PATH}/${SSL_CERT_FILE}"
KEY_PATH="${SSL_CERTS_HOST_PATH}/${SSL_KEY_FILE}"

[[ -f "${CERT_PATH}" ]] || fail "No existe el certificado: ${CERT_PATH}"
[[ -f "${KEY_PATH}" ]] || fail "No existe la clave privada: ${KEY_PATH}"

log "Generando export Web previo al despliegue temporal"
GODOT_BIN="${GODOT_BIN:-}" \
EXPORT_MODE="${EXPORT_MODE}" \
EXPORT_PRESET="${EXPORT_PRESET:-}" \
WEB_EXPORT_PATH="${WEB_EXPORT_PATH}" \
WEB_EXPORT_CLEAN="${WEB_EXPORT_CLEAN}" \
  "${SCRIPT_DIR}/export_to_web.sh"

EXPORT_HTML_ABS="$(to_abs_path "${WEB_EXPORT_PATH}")"
EXPORT_DIR="$(dirname "${EXPORT_HTML_ABS}")"
EXPORT_ENTRY_HTML="$(basename "${EXPORT_HTML_ABS}")"
EXPORT_ENTRY_BASENAME="${EXPORT_ENTRY_HTML%.*}"

BROTLI_JS_FILE="${EXPORT_ENTRY_BASENAME}.js"
BROTLI_PCK_FILE="${EXPORT_ENTRY_BASENAME}.pck"
BROTLI_SIDE_WASM_FILE="${EXPORT_ENTRY_BASENAME}.side.wasm"

if [[ "${WEB_BROTLI_COMPRESS}" == "1" ]]; then
  compress_brotli_assets_in_dir \
    "${EXPORT_DIR}" \
    "${BROTLI_SIDE_WASM_FILE}" \
    "${BROTLI_PCK_FILE}" \
    "${BROTLI_JS_FILE}"
else
  log "Compresion Brotli omitida (WEB_BROTLI_COMPRESS=0)"
fi

mapfile -t wildcard_domains < <(extract_wildcards_from_san "${CERT_PATH}")

if [[ "${#wildcard_domains[@]}" -eq 0 ]]; then
  subject_wildcard="$(extract_wildcard_from_subject "${CERT_PATH}")"
  if [[ -n "${subject_wildcard}" ]]; then
    wildcard_domains=("${subject_wildcard}")
  fi
fi

if [[ "${#wildcard_domains[@]}" -eq 0 ]]; then
  fail "No se encontro ningun wildcard en el certificado (${CERT_PATH})."
fi

selected_wildcard_domain=""
if [[ -n "${WILDCARD_HINT:-}" ]]; then
  wildcard_hint="${WILDCARD_HINT#*.}"
  wildcard_hint="${wildcard_hint,,}"
  for wildcard_domain in "${wildcard_domains[@]}"; do
    if [[ "${wildcard_domain}" == "${wildcard_hint}" ]]; then
      selected_wildcard_domain="${wildcard_domain}"
      break
    fi
  done
  [[ -n "${selected_wildcard_domain}" ]] || fail "WILDCARD_HINT='${WILDCARD_HINT}' no coincide con los wildcard del certificado: ${wildcard_domains[*]}"
else
  selected_wildcard_domain="${wildcard_domains[0]}"
fi

commit_hash="$(git -C "${PROJECT_ROOT}" rev-parse --short=8 HEAD 2>/dev/null || true)"
[[ -n "${commit_hash}" ]] || fail "No se pudo obtener el hash del ultimo commit."
commit_hash="${commit_hash,,}"

domain_prefix="${TEMP_DOMAIN_PREFIX:-${commit_hash}}"
domain_prefix="${domain_prefix,,}"
temp_domain="${domain_prefix}.${selected_wildcard_domain}"

if ! printf '%s' "${temp_domain}" | grep -Eq '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9-]+)+$'; then
  fail "El dominio temporal generado no es valido: ${temp_domain}"
fi

ensure_hosts_entry "${temp_domain}"

mkdir -p "${TMP_ROOT}"
deploy_id="${commit_hash}_$(date +%Y%m%d%H%M%S)"
work_dir="${TMP_ROOT}/${deploy_id}"
compose_file="${work_dir}/docker-compose.yml"
dockerfile_path="${work_dir}/Dockerfile"
nginx_main_conf_path="${work_dir}/nginx.conf"
nginx_conf_path="${work_dir}/default.conf"
auto_down_script="${work_dir}/auto_down.sh"
state_file="${TMP_ROOT}/last_deploy.env"
compose_project="temp_web_${commit_hash}_$(date +%H%M%S)"

mkdir -p "${work_dir}"

cat > "${nginx_main_conf_path}" <<'EOF'
load_module /usr/lib/nginx/modules/ngx_http_brotli_filter_module.so;
load_module /usr/lib/nginx/modules/ngx_http_brotli_static_module.so;

user nginx;
worker_processes auto;

error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
  worker_connections 1024;
}

http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                  '$status $body_bytes_sent "$http_referer" '
                  '"$http_user_agent" "$http_x_forwarded_for"';

  access_log /var/log/nginx/access.log main;

  sendfile on;
  keepalive_timeout 65;

  include /etc/nginx/conf.d/*.conf;
}
EOF

cat > "${nginx_conf_path}" <<EOF
server {
  listen 80;
  listen [::]:80;
  server_name ${temp_domain};

  # Keep HTTP enabled without redirect for temporary previews.
  add_header Cross-Origin-Opener-Policy "same-origin" always;
  add_header Cross-Origin-Embedder-Policy "require-corp" always;
  add_header Cross-Origin-Resource-Policy "same-origin" always;

  root /usr/share/nginx/html;
  index ${EXPORT_ENTRY_HTML};

  location ~ \.js$ {
    brotli_static on;
    default_type text/javascript;
    add_header Vary "Accept-Encoding" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    try_files \$uri =404;
  }

  location ~ \.wasm$ {
    brotli_static on;
    default_type application/wasm;
    add_header Vary "Accept-Encoding" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    try_files \$uri =404;
  }

  location ~ \.pck$ {
    brotli_static on;
    default_type application/octet-stream;
    add_header Vary "Accept-Encoding" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    try_files \$uri =404;
  }

  location / {
    brotli_static on;
    add_header Vary "Accept-Encoding" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    try_files \$uri \$uri/ /${EXPORT_ENTRY_HTML}\$is_args\$args;
  }
}

server {
  listen 443 ssl;
  listen [::]:443 ssl;
  server_name ${temp_domain};

  ssl_certificate /certs/${SSL_CERT_FILE};
  ssl_certificate_key /certs/${SSL_KEY_FILE};
  ssl_session_timeout 1d;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!aNULL:!MD5;

  # Required by Godot Web export when threads/SharedArrayBuffer are used.
  add_header Cross-Origin-Opener-Policy "same-origin" always;
  add_header Cross-Origin-Embedder-Policy "require-corp" always;
  add_header Cross-Origin-Resource-Policy "same-origin" always;

  root /usr/share/nginx/html;
  index ${EXPORT_ENTRY_HTML};

  location ~ \.js$ {
    brotli_static on;
    default_type text/javascript;
    add_header Vary "Accept-Encoding" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    try_files \$uri =404;
  }

  location ~ \.wasm$ {
    brotli_static on;
    default_type application/wasm;
    add_header Vary "Accept-Encoding" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    try_files \$uri =404;
  }

  location ~ \.pck$ {
    brotli_static on;
    default_type application/octet-stream;
    add_header Vary "Accept-Encoding" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    try_files \$uri =404;
  }

  location / {
    brotli_static on;
    add_header Vary "Accept-Encoding" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    try_files \$uri \$uri/ /${EXPORT_ENTRY_HTML}\$is_args\$args;
  }
}
EOF

cat > "${dockerfile_path}" <<'EOF'
FROM alpine:3.21

RUN apk add --no-cache nginx nginx-mod-http-brotli \
    && mkdir -p /run/nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
EOF

cat > "${compose_file}" <<EOF
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: "${compose_project}-nginx"
    ports:
      - "${TEMP_WEB_HTTP_PORT}:80"
      - "${TEMP_WEB_HTTPS_PORT}:443"
    volumes:
      - "${EXPORT_DIR}:/usr/share/nginx/html:ro"
      - "${SSL_CERTS_HOST_PATH}:/certs:ro"
    restart: "no"
EOF

log "Levantando docker compose temporal (${compose_project})"
"${COMPOSE_CMD[@]}" -f "${compose_file}" -p "${compose_project}" up -d --build

declare -a AUTO_DOWN_COMPOSE_CMD
if (( DOCKER_NEEDS_SUDO )); then
  AUTO_DOWN_COMPOSE_CMD=("${COMPOSE_CMD[@]:2}")
else
  AUTO_DOWN_COMPOSE_CMD=("${COMPOSE_CMD[@]}")
fi

auto_down_compose_cmd_quoted="$(printf '%q ' "${AUTO_DOWN_COMPOSE_CMD[@]}")"
compose_file_quoted="$(printf '%q' "${compose_file}")"
compose_project_quoted="$(printf '%q' "${compose_project}")"
work_dir_quoted="$(printf '%q' "${work_dir}")"

cat > "${auto_down_script}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
sleep ${TEMP_TTL_SECONDS}
${auto_down_compose_cmd_quoted}-f ${compose_file_quoted} -p ${compose_project_quoted} down --remove-orphans >/dev/null 2>&1 || true
rm -rf ${work_dir_quoted}
EOF

chmod +x "${auto_down_script}"
if (( DOCKER_NEEDS_SUDO )); then
  sudo -n nohup "${auto_down_script}" >/dev/null 2>&1 &
else
  nohup "${auto_down_script}" >/dev/null 2>&1 &
fi

expires_at_epoch="$(( $(date +%s) + TEMP_TTL_SECONDS ))"
cat > "${state_file}" <<EOF
TEMP_DOMAIN=${temp_domain}
COMPOSE_PROJECT=${compose_project}
COMPOSE_FILE=${compose_file}
EXPIRES_AT_EPOCH=${expires_at_epoch}
SSL_CERTS_HOST_PATH=${SSL_CERTS_HOST_PATH}
TEMP_WEB_HTTP_PORT=${TEMP_WEB_HTTP_PORT}
TEMP_WEB_HTTPS_PORT=${TEMP_WEB_HTTPS_PORT}
EOF

preview_url_http="$(build_url "http" "${temp_domain}" "${TEMP_WEB_HTTP_PORT}" "80")"
preview_url_https="$(build_url "https" "${temp_domain}" "${TEMP_WEB_HTTPS_PORT}" "443")"
lan_ipv4="$(detect_default_ipv4 || true)"
preview_url_lan_http=""
preview_url_lan_https=""

if [[ -n "${lan_ipv4}" ]]; then
  preview_url_lan_http="$(build_url "http" "${lan_ipv4}" "${TEMP_WEB_HTTP_PORT}" "80")"
  preview_url_lan_https="$(build_url "https" "${lan_ipv4}" "${TEMP_WEB_HTTPS_PORT}" "443")"
fi

log "Despliegue temporal completado."
log "Wildcard detectado: *.${selected_wildcard_domain}"
log "Dominio temporal: ${temp_domain}"
log "URL HTTP: ${preview_url_http}"
log "URL HTTPS: ${preview_url_https}"
if [[ -n "${preview_url_lan_http}" ]]; then
  log "URL LAN HTTP: ${preview_url_lan_http}"
fi
if [[ -n "${preview_url_lan_https}" ]]; then
  log "URL LAN HTTPS: ${preview_url_lan_https}"
  log "Nota: el QR usa HTTPS por IP, pero el navegador puede advertir mismatch si el certificado no incluye esa IP."
  print_terminal_qr "${preview_url_lan_https}"
else
  print_terminal_qr "${preview_url_https}"
fi
log "El contenedor se apagara automaticamente en ${TEMP_TTL_SECONDS} segundos (15 minutos por defecto)."

dns_script_path="${PROJECT_ROOT}/scripts/deploy_temp_dns.sh"
if [[ -f "${dns_script_path}" ]]; then
  dns_script_path_quoted="$(printf '%q' "${dns_script_path}")"
  dns_target_ip_hint="${lan_ipv4}"
  if [[ -n "${dns_target_ip_hint}" ]]; then
    dns_deploy_cmd="TEMP_DNS_DOMAIN=${temp_domain} TEMP_DNS_TARGET_IP=${dns_target_ip_hint} ${dns_script_path_quoted}"
  else
    dns_deploy_cmd="TEMP_DNS_DOMAIN=${temp_domain} ${dns_script_path_quoted}"
  fi

  log "Comando para desplegar DNS temporal (copiar y ejecutar):"
  printf '%s\n' "${dns_deploy_cmd}"
fi
