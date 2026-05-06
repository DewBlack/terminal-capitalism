#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
UPLOAD_SCRIPT="${SCRIPT_DIR}/upload_itch_web.sh"
PACKAGE_SCRIPT="${SCRIPT_DIR}/export_and_package_itch_web.sh"

log() {
  printf '[auto-itch] %s\n' "$*"
}

warn() {
  printf '[auto-itch][WARN] %s\n' "$*" >&2
}

TRIGGER_SOURCE="${1:-unknown}"

if [[ "${TC_AUTO_DEPLOY_ITCH:-1}" != "1" ]]; then
  log "TC_AUTO_DEPLOY_ITCH=0, despliegue automatico desactivado."
  exit 0
fi

CURRENT_BRANCH="$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
  log "Rama actual '${CURRENT_BRANCH:-desconocida}', se omite auto deploy."
  exit 0
fi

CONFIG_PATH="${ITCH_DEPLOY_ENV_FILE:-${PROJECT_ROOT}/.local/itch_deploy.env}"
if [[ ! -f "${CONFIG_PATH}" ]]; then
  log "No existe ${CONFIG_PATH}. No se despliega nada."
  log "Crea el archivo usando scripts/utils/itch_deploy.env.example."
  exit 0
fi

set -a
# shellcheck source=/dev/null
source "${CONFIG_PATH}"
set +a

ITCH_DEPLOY_MODE="${ITCH_DEPLOY_MODE:-upload}"
ITCH_CHANNEL="${ITCH_CHANNEL:-web}"
SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_EXPORT="${SKIP_EXPORT:-0}"

case "${ITCH_DEPLOY_MODE}" in
  offline)
    if [[ ! -x "${PACKAGE_SCRIPT}" ]]; then
      warn "No existe o no es ejecutable: ${PACKAGE_SCRIPT}"
      exit 0
    fi

    log "Hook ${TRIGGER_SOURCE}: modo offline (solo export + zip local)"
    if (
      cd "${PROJECT_ROOT}"
      EXPORT_MODE="${EXPORT_MODE:-release}" \
      WEB_EXPORT_PATH="${WEB_EXPORT_PATH:-Builds/Web/index.html}" \
      ITCH_OUT_DIR="${ITCH_OUT_DIR:-Builds/Itch/web}" \
      ITCH_ZIP_NAME="${ITCH_ZIP_NAME:-terminal-capitalism-web-itch.zip}" \
      SKIP_EXPORT="${SKIP_EXPORT}" \
      "${PACKAGE_SCRIPT}"
    ); then
      log "Modo offline completado."
    else
      warn "El empaquetado offline fallo, pero no se interrumpe tu flujo de git."
    fi
    ;;
  upload)
    if [[ ! -x "${UPLOAD_SCRIPT}" ]]; then
      warn "No existe o no es ejecutable: ${UPLOAD_SCRIPT}"
      exit 0
    fi

    if [[ -z "${ITCH_TARGET:-}" ]]; then
      warn "Falta ITCH_TARGET en ${CONFIG_PATH} (formato: usuario/juego)."
      exit 0
    fi

    if [[ "${ITCH_TARGET}" == "tuusuario/"* ]]; then
      log "ITCH_TARGET sigue en valor de ejemplo (${ITCH_TARGET}). Se omite auto deploy."
      exit 0
    fi

    if ! command -v butler >/dev/null 2>&1; then
      warn "butler no esta instalado en este entorno. Se omite auto deploy."
      exit 0
    fi

    log "Hook ${TRIGGER_SOURCE}: exportando y subiendo a ${ITCH_TARGET}:${ITCH_CHANNEL}"
    if (
      cd "${PROJECT_ROOT}"
      ITCH_VERSION="${ITCH_VERSION:-}" \
      SKIP_BUILD="${SKIP_BUILD}" \
      EXPORT_MODE="${EXPORT_MODE:-release}" \
      WEB_EXPORT_PATH="${WEB_EXPORT_PATH:-Builds/Web/index.html}" \
      ITCH_PACKAGE_DIR="${ITCH_PACKAGE_DIR:-Builds/Itch/web/package}" \
      "${UPLOAD_SCRIPT}" "${ITCH_TARGET}" "${ITCH_CHANNEL}"
    ); then
      log "Auto deploy terminado."
    else
      warn "El auto deploy fallo, pero no se interrumpe tu flujo de git."
    fi
    ;;
  *)
    warn "ITCH_DEPLOY_MODE invalido: ${ITCH_DEPLOY_MODE}. Valores: upload, offline."
    ;;
esac

exit 0
