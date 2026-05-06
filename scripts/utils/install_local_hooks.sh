#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
HOOKS_DIR="${PROJECT_ROOT}/.githooks"

log() {
  printf '[hooks-install] %s\n' "$*"
}

fail() {
  printf '[hooks-install][ERROR] %s\n' "$*" >&2
  exit 1
}

[[ -d "${PROJECT_ROOT}/.git" ]] || fail "No se encontro .git en ${PROJECT_ROOT}"
[[ -d "${HOOKS_DIR}" ]] || fail "No existe carpeta de hooks: ${HOOKS_DIR}"

chmod +x \
  "${HOOKS_DIR}/post-merge" \
  "${HOOKS_DIR}/post-rewrite" \
  "${PROJECT_ROOT}/scripts/utils/auto_deploy_itch_after_pull.sh" \
  "${PROJECT_ROOT}/scripts/utils/upload_itch_web.sh" \
  "${PROJECT_ROOT}/scripts/utils/export_and_package_itch_web.sh" \
  "${PROJECT_ROOT}/scripts/utils/export_to_web.sh"

git -C "${PROJECT_ROOT}" config core.hooksPath .githooks

log "Hooks instalados."
log "core.hooksPath -> .githooks"
log "Siguiente paso: edita .local/itch_deploy.env y define ITCH_DEPLOY_MODE=offline o upload."
