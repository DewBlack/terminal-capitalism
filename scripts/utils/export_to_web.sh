#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
TMP_ROOT="${PROJECT_ROOT}/.tmp/web_export"
PROJECT_WEB_BUILD_ROOT="${PROJECT_ROOT}/Builds/Web"

log() {
  printf '[export-web] %s\n' "$*"
}

fail() {
  printf '[export-web][ERROR] %s\n' "$*" >&2
  exit 1
}

on_unexpected_error() {
  local exit_code="$1"
  local line="$2"
  local command="$3"

  printf '[export-web][ERROR] Fallo inesperado (exit %s) en linea %s: %s\n' "${exit_code}" "${line}" "${command}" >&2
}

trap 'on_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR

need_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || fail "No se encontro el comando requerido: ${cmd}"
}

resolve_godot_bin() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    if command -v "${GODOT_BIN}" >/dev/null 2>&1 || [[ -x "${GODOT_BIN}" ]]; then
      printf '%s\n' "${GODOT_BIN}"
      return
    fi
    fail "GODOT_BIN no es ejecutable ni existe en PATH: ${GODOT_BIN}"
  fi

  if command -v godot4 >/dev/null 2>&1; then
    printf '%s\n' "godot4"
    return
  fi

  if command -v godot >/dev/null 2>&1; then
    printf '%s\n' "godot"
    return
  fi

  fail "No se encontro Godot CLI. Define GODOT_BIN."
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

detect_web_export_preset() {
  local presets_file="${PROJECT_ROOT}/export_presets.cfg"
  [[ -f "${presets_file}" ]] || return 0

  awk -F= '
    function extract_value(line,   value) {
      value = line
      sub(/^[^=]*=/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      return value
    }
    function emit_if_web() {
      if (emitted) {
        return
      }
      if (in_preset && platform == "Web" && name != "") {
        emitted = 1
        print name
        exit
      }
    }
    /^\[preset\.[0-9]+\]$/ {
      emit_if_web()
      in_preset = 1
      name = ""
      platform = ""
      next
    }
    /^\[preset\.[0-9]+\.options\]$/ {
      emit_if_web()
      in_preset = 0
      next
    }
    in_preset && /^name=/ {
      name = extract_value($0)
    }
    in_preset && /^platform=/ {
      platform = extract_value($0)
    }
    END {
      if (!emitted) {
        emit_if_web()
      }
    }
  ' "${presets_file}"
}

detect_web_export_path() {
  local target_preset="${1:-}"
  local presets_file="${PROJECT_ROOT}/export_presets.cfg"
  [[ -f "${presets_file}" ]] || return 0

  awk -F= -v target_preset="${target_preset}" '
    function extract_value(line,   value) {
      value = line
      sub(/^[^=]*=/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      return value
    }
    function emit_if_match() {
      if (emitted) {
        return
      }
      if (!in_preset) {
        return
      }
      if (platform != "Web" || export_path == "") {
        return
      }
      if (target_preset == "" || name == target_preset) {
        emitted = 1
        print export_path
        exit
      }
    }
    /^\[preset\.[0-9]+\]$/ {
      emit_if_match()
      in_preset = 1
      name = ""
      platform = ""
      export_path = ""
      next
    }
    /^\[preset\.[0-9]+\.options\]$/ {
      emit_if_match()
      in_preset = 0
      next
    }
    in_preset && /^name=/ {
      name = extract_value($0)
    }
    in_preset && /^platform=/ {
      platform = extract_value($0)
    }
    in_preset && /^export_path=/ {
      export_path = extract_value($0)
    }
    END {
      if (!emitted) {
        emit_if_match()
      }
    }
  ' "${presets_file}"
}

to_abs_path() {
  local path_value="$1"

  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
    return
  fi

  printf '%s\n' "${PROJECT_ROOT}/${path_value#./}"
}

resolve_default_export_path() {
  local preset_export_path="$1"

  if [[ -n "${preset_export_path}" ]]; then
    printf '%s\n' "${preset_export_path}"
    return
  fi

  printf '%s\n' "Builds/Web/index.html"
}

validate_web_artifacts() {
  local export_html_abs="$1"
  local export_dir="$2"
  local export_base="${export_html_abs%.*}"

  [[ -f "${export_html_abs}" ]] || fail "No se genero el HTML exportado: ${export_html_abs}"
  [[ -f "${export_base}.pck" ]] || fail "No se genero el paquete .pck esperado: ${export_base}.pck"

  if ! find "${export_dir}" -maxdepth 1 -type f -name '*.wasm' | grep -q .; then
    fail "No se encontro ningun artefacto .wasm en ${export_dir}"
  fi
}

print_usage() {
  cat <<'EOF'
Uso:
  ./scripts/utils/export_to_web.sh

Variables de entorno:
  GODOT_BIN        (opcional) Binario Godot CLI. Default: godot4/godot detectado
  EXPORT_MODE      (opcional) release o debug. Default: release
  EXPORT_PRESET    (opcional) Preset Godot Web. Default: primer preset con platform=Web
  WEB_EXPORT_PATH  (opcional) Ruta del HTML exportado. Default: export_path del preset Web o Builds/Web/index.html
  WEB_EXPORT_CLEAN (opcional) Si vale 1, limpia el staging antes de exportar. Default: 1

Ejemplos:
  ./scripts/utils/export_to_web.sh

  EXPORT_MODE=debug \
  WEB_EXPORT_PATH=Builds/Web/index.html \
  ./scripts/utils/export_to_web.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

need_cmd awk
need_cmd find

GODOT_BIN_RESOLVED="$(resolve_godot_bin)"

EXPORT_MODE="${EXPORT_MODE:-debug}"
case "${EXPORT_MODE}" in
  release|debug) ;;
  *) fail "EXPORT_MODE invalido: ${EXPORT_MODE}. Valores permitidos: release, debug." ;;
esac

WEB_EXPORT_CLEAN="${WEB_EXPORT_CLEAN:-1}"
validate_boolean_flag "${WEB_EXPORT_CLEAN}" "WEB_EXPORT_CLEAN"

EXPORT_PRESET="${EXPORT_PRESET:-$(detect_web_export_preset)}"
[[ -n "${EXPORT_PRESET}" ]] || fail "No se encontro ningun preset con platform=\"Web\" en export_presets.cfg. Define EXPORT_PRESET."

PRESET_EXPORT_PATH="$(detect_web_export_path "${EXPORT_PRESET}")"
DEFAULT_EXPORT_PATH="$(resolve_default_export_path "${PRESET_EXPORT_PATH}")"
WEB_EXPORT_PATH_RAW="${WEB_EXPORT_PATH:-${DEFAULT_EXPORT_PATH}}"
WEB_EXPORT_PATH_ABS="$(to_abs_path "${WEB_EXPORT_PATH_RAW}")"
EXPORT_DIR="$(dirname "${WEB_EXPORT_PATH_ABS}")"

if [[ "${WEB_EXPORT_CLEAN}" == "1" ]]; then
  case "${EXPORT_DIR}" in
    "${TMP_ROOT}"|\
    "${TMP_ROOT}"/*|\
    "${PROJECT_WEB_BUILD_ROOT}"|\
    "${PROJECT_WEB_BUILD_ROOT}"/*) ;;
    *)
      fail "WEB_EXPORT_CLEAN=1 solo se permite cuando WEB_EXPORT_PATH apunta dentro de ${PROJECT_WEB_BUILD_ROOT} o ${TMP_ROOT}. Define WEB_EXPORT_CLEAN=0 para usar otra ruta."
      ;;
  esac
  log "Limpiando staging de export en ${EXPORT_DIR}"
  rm -rf -- "${EXPORT_DIR}"
fi
mkdir -p "${EXPORT_DIR}"

if [[ "${EXPORT_MODE}" == "release" ]]; then
  GODOT_EXPORT_FLAG="--export-release"
else
  GODOT_EXPORT_FLAG="--export-debug"
fi

log "Exportando Godot Web (${EXPORT_MODE}) con preset '${EXPORT_PRESET}' a ${WEB_EXPORT_PATH_ABS}"
export_base="${WEB_EXPORT_PATH_ABS%.*}"
export_exit_code=0
if "${GODOT_BIN_RESOLVED}" --headless --recovery-mode --path "${PROJECT_ROOT}" "${GODOT_EXPORT_FLAG}" "${EXPORT_PRESET}" "${WEB_EXPORT_PATH_ABS}"; then
  :
else
  export_exit_code=$?
  if [[ "${export_exit_code}" -eq 139 ]] \
    && [[ -f "${WEB_EXPORT_PATH_ABS}" ]] \
    && [[ -f "${export_base}.pck" ]] \
    && find "${EXPORT_DIR}" -maxdepth 1 -type f -name '*.wasm' | grep -q .; then
    log "Godot finalizo con SIGSEGV (139) tras exportar, pero los artefactos Web existen. Se continua."
  else
    fail "Fallo la exportacion de Godot (codigo ${export_exit_code})."
  fi
fi

validate_web_artifacts "${WEB_EXPORT_PATH_ABS}" "${EXPORT_DIR}"

log "Export completado."
log "Preset usado: ${EXPORT_PRESET}"
log "Archivo HTML: ${WEB_EXPORT_PATH_ABS}"
log "Directorio exportado: ${EXPORT_DIR}"
