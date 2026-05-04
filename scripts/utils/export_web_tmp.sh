#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXPORT_PRESETS_FILE="$PROJECT_ROOT/export_presets.cfg"

MODE="release"
SERVE=0
PORT="8060"
CLEAN=1
PRESET_NAME="${WEB_PRESET:-}"
OUT_DIR="${WEB_BUILD_DIR:-$PROJECT_ROOT/builds/web_tmp}"
GODOT_BIN="${GODOT_BIN:-}"

usage() {
  cat <<USAGE
Uso:
  $(basename "$0") [opciones]

Opciones:
  --release             Exporta con --export-release (default)
  --debug               Exporta con --export-debug
  --preset <nombre>     Nombre del preset de export (si no, autodetecta Web/HTML5)
  --out <dir>           Directorio de salida (default: builds/web_tmp)
  --serve               Levanta servidor local al terminar
  --port <n>            Puerto para --serve (default: 8060)
  --no-clean            No borra el directorio de salida antes de exportar
  --godot <binario>     Ruta al binario de Godot (si no, intenta autodetectar)
  -h, --help            Muestra esta ayuda

Variables opcionales:
  GODOT_BIN, WEB_PRESET, WEB_BUILD_DIR

Ejemplos:
  $(basename "$0") --serve
  $(basename "$0") --debug --preset "Web" --out builds/web_debug --serve --port 9000
USAGE
}

log() { printf '[web-export] %s\n' "$*"; }
err() { printf '[web-export][error] %s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      MODE="release"
      shift
      ;;
    --debug)
      MODE="debug"
      shift
      ;;
    --preset)
      PRESET_NAME="${2:-}"
      shift 2
      ;;
    --out)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --serve)
      SERVE=1
      shift
      ;;
    --port)
      PORT="${2:-}"
      shift 2
      ;;
    --no-clean)
      CLEAN=0
      shift
      ;;
    --godot)
      GODOT_BIN="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Opcion no reconocida: $1"
      usage
      exit 1
      ;;
  esac
done

resolve_godot_bin() {
  if [[ -n "$GODOT_BIN" ]]; then
    if [[ ! -x "$GODOT_BIN" ]]; then
      err "El binario indicado no es ejecutable: $GODOT_BIN"
      exit 1
    fi
    return
  fi

  if command -v godot4 >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot4)"
    return
  fi
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
    return
  fi

  err "No se encontro Godot en PATH. Usa --godot o GODOT_BIN."
  exit 1
}

list_preset_names() {
  if [[ ! -f "$EXPORT_PRESETS_FILE" ]]; then
    return 0
  fi
  sed -n 's/^name="\(.*\)"$/\1/p' "$EXPORT_PRESETS_FILE"
}

auto_detect_preset() {
  local names
  mapfile -t names < <(list_preset_names)

  if [[ ${#names[@]} -eq 0 ]]; then
    return 1
  fi

  local n
  for n in "${names[@]}"; do
    local low
    low="$(printf '%s' "$n" | tr '[:upper:]' '[:lower:]')"
    if [[ "$low" == *"web"* || "$low" == *"html5"* ]]; then
      PRESET_NAME="$n"
      return 0
    fi
  done

  return 1
}

ensure_export_preset() {
  if [[ ! -f "$EXPORT_PRESETS_FILE" ]]; then
    err "No existe export_presets.cfg en el proyecto."
    err "Abre Godot -> Project -> Export... y crea un preset Web (HTML5), luego reintenta."
    exit 1
  fi

  if [[ -z "$PRESET_NAME" ]]; then
    if ! auto_detect_preset; then
      err "No pude autodetectar un preset Web/HTML5."
      err "Presets disponibles:"
      list_preset_names | sed 's/^/  - /' >&2 || true
      err "Pasa --preset \"NombreExacto\""
      exit 1
    fi
  fi

  if ! list_preset_names | rg -Fqx "$PRESET_NAME"; then
    err "El preset '$PRESET_NAME' no existe en export_presets.cfg"
    err "Presets disponibles:"
    list_preset_names | sed 's/^/  - /' >&2 || true
    exit 1
  fi
}

resolve_godot_bin
ensure_export_preset

mkdir -p "$OUT_DIR"
if [[ "$CLEAN" -eq 1 ]]; then
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"
fi

OUT_HTML="$OUT_DIR/index.html"

log "Proyecto: $PROJECT_ROOT"
log "Godot: $GODOT_BIN"
log "Preset: $PRESET_NAME"
log "Modo: $MODE"
log "Salida: $OUT_HTML"

if [[ "$MODE" == "debug" ]]; then
  "$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-debug "$PRESET_NAME" "$OUT_HTML"
else
  "$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-release "$PRESET_NAME" "$OUT_HTML"
fi

if [[ ! -f "$OUT_HTML" ]]; then
  err "Export finalizado pero no se encontro $OUT_HTML"
  exit 1
fi

log "Export web completado."
log "Prueba local sugerida: python3 -m http.server 8060 --directory '$OUT_DIR'"
log "URL: http://localhost:8060"

if [[ "$SERVE" -eq 1 ]]; then
  log "Levantando servidor local en puerto $PORT..."
  log "Abre: http://localhost:$PORT"
  exec python3 -m http.server "$PORT" --directory "$OUT_DIR"
fi
