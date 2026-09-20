#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# ESP32-S3-4848S040
# BLOCK 3 | COMPILE BOTH LAYERS + FLASH + BOOT MONITOR
#
# Layer A: ESPHome + LVGL + ST7701S + GT911 + 480x480
# Layer B: PlatformIO + Arduino-GFX + GT911(I2C) + Wi-Fi + HTTP/API
#
# Both layers are compiled. Only one firmware image is flashed.
# ============================================================

cd "$(dirname "$0")/.."

REPO_DIR="${REPO_DIR:-$(pwd)}"
VENV_DIR="${VENV_DIR:-${REPO_DIR}/.venv}"

CONFIG="${REPO_DIR}/src/main.yaml"
LOCAL_CONFIG="${REPO_DIR}/include/local_config.h"
SECRETS="${REPO_DIR}/src/secrets.yaml"

PIO_ENV="${PIO_ENV:-panel_4848s040}"
ESPHOME_VERSION="${ESPHOME_VERSION:-2026.8.2}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION:-6.2.0}"

BUILD_MODE="${BUILD_MODE:-real}"
BUILD_PLATFORMIO="${BUILD_PLATFORMIO:-1}"

LAYER="${LAYER:-platformio}"
PORT="${PORT:-}"
BAUD="${BAUD:-115200}"
OPEN_MONITOR="${OPEN_MONITOR:-true}"

LOG_DIR="${REPO_DIR}/.ci"
LOG_FILE="${LOG_DIR}/flash-monitor.log"
BUILD_LOG="${LOG_DIR}/build.log"

mkdir -p "${LOG_DIR}"

usage() {
  cat <<'EOF'
Uso:
  BUILD_MODE=real ./scripts/flash-panel.sh --layer platformio --port /dev/ttyACM0
  BUILD_MODE=real ./scripts/flash-panel.sh --layer esphome --port /dev/ttyACM0
  BUILD_MODE=real ./scripts/flash-panel.sh --layer platformio

Opciones:
  --layer platformio|esphome
  --port /dev/ttyACM0
  --baud 115200
  --monitor
  --no-monitor
  --help

Las dos capas se compilan. Solo la capa indicada por --layer se flashea
al ESP32 en esa ejecución.
EOF
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

on_error() {
  local rc=$?
  echo
  echo "============================================================" | tee -a "${LOG_FILE}"
  echo "[ERROR] BLOCK 3 FAILED" | tee -a "${LOG_FILE}"
  echo "Exit code : ${rc}" | tee -a "${LOG_FILE}"
  echo "Line      : ${BASH_LINENO[0]:-unknown}" | tee -a "${LOG_FILE}"
  echo "Command   : ${BASH_COMMAND:-unknown}" | tee -a "${LOG_FILE}"
  echo "PWD       : $(pwd)" | tee -a "${LOG_FILE}"
  echo "Layer     : ${LAYER}" | tee -a "${LOG_FILE}"
  echo "Build log : ${BUILD_LOG}" | tee -a "${LOG_FILE}"
  echo "Flash log : ${LOG_FILE}" | tee -a "${LOG_FILE}"
  echo
  ls -l /dev/ttyACM* /dev/ttyUSB* 2>/dev/null | tee -a "${LOG_FILE}" || true
  exit "${rc}"
}
trap on_error ERR

on_interrupt() {
  echo | tee -a "${LOG_FILE}"
  echo "[INFO] Monitor detenido por Ctrl+C." | tee -a "${LOG_FILE}"
  exit 0
}
trap on_interrupt INT TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    --layer)
      [[ $# -ge 2 ]] || die "--layer requiere platformio o esphome."
      LAYER="$2"
      shift 2
      ;;
    --port|-p)
      [[ $# -ge 2 ]] || die "--port requiere una ruta."
      PORT="$2"
      shift 2
      ;;
    --baud)
      [[ $# -ge 2 ]] || die "--baud requiere un valor."
      BAUD="$2"
      shift 2
      ;;
    --monitor|-m)
      OPEN_MONITOR="true"
      shift
      ;;
    --no-monitor)
      OPEN_MONITOR="false"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Argumento desconocido: $1"
      ;;
  esac
done

case "${LAYER}" in
  platformio|esphome) ;;
  *) die "LAYER debe ser platformio o esphome." ;;
esac

[[ "${BUILD_MODE}" == "real" ]] || die "BLOCK 3 requiere BUILD_MODE=real."
[[ -d "${REPO_DIR}/.git" ]] || die "No es un repositorio Git: ${REPO_DIR}"
[[ -f "${CONFIG}" ]] || die "Falta: ${CONFIG}"
[[ -f "${VENV_DIR}/bin/activate" ]] || die "Falta .venv. Ejecuta BLOCK 1."

source "${VENV_DIR}/bin/activate"

command -v esphome >/dev/null 2>&1 || die "ESPHome no está disponible."
command -v pio >/dev/null 2>&1 || die "PlatformIO no está disponible."

echo "============================================================" | tee "${LOG_FILE}"
echo " ESP32-S3-4848S040" | tee -a "${LOG_FILE}"
echo " BLOCK 3 | COMPILE BOTH + FLASH + BOOT MONITOR" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo "Repository : ${REPO_DIR}" | tee -a "${LOG_FILE}"
echo "Branch     : $(git branch --show-current)" | tee -a "${LOG_FILE}"
echo "Commit     : $(git log -1 --oneline --decorate)" | tee -a "${LOG_FILE}"
echo "ESPHome    : $(esphome version)" | tee -a "${LOG_FILE}"
echo "PlatformIO : $(pio --version)" | tee -a "${LOG_FILE}"
echo "Flash layer: ${LAYER}" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# VERIFY ACTUAL LIBRARIES / HARDWARE CONTRACT
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== VERIFY LIBRARIES / HARDWARE ===" | tee -a "${LOG_FILE}"

grep -q '^lvgl:' "${CONFIG}" || die "ESPHome LVGL no está declarado."
grep -q 'platform: gt911' "${CONFIG}" || die "ESPHome GT911 no está declarado."
grep -q 'platform: st7701s' "${CONFIG}" || die "ESPHome ST7701S no está declarado."
grep -q 'width: 480' "${CONFIG}" || die "ESPHome width=480 no está declarado."
grep -q 'height: 480' "${CONFIG}" || die "ESPHome height=480 no está declarado."

grep -Fq 'moononournation/GFX Library for Arduino@1.5.9' "${REPO_DIR}/platformio.ini" ||   die "PlatformIO no declara GFX Library for Arduino 1.5.9."
grep -Fq '#include <Arduino_GFX_Library.h>' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||   die "PlatformIO no usa Arduino_GFX_Library."
grep -Fq '#include <Wire.h>' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||   die "PlatformIO no usa Wire/GT911."
grep -Fq '#include <WiFi.h>' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||   die "PlatformIO no usa WiFi."
grep -Fq '#include <HTTPClient.h>' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||   die "PlatformIO no usa HTTPClient."
grep -Fq 'kTouchAddress = 0x5D' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||   die "GT911 0x5D no está definido en PlatformIO."
grep -Fq 'kScreenWidth = 480' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||   die "PlatformIO width=480 no está definido."
grep -Fq 'kScreenHeight = 480' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||   die "PlatformIO height=480 no está definido."
grep -Fq 'commandBuffer' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||   die "commandBuffer no está integrado."
grep -Fq '/api/device/v1/commands' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||   die "API de commands no está integrada."
grep -Fq '2500UL' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||   die "Polling 2.5 s no está integrado."

# PlatformIO 3C deliberately does not link a second LVGL instance.
if grep -Fq 'lvgl/lvgl' "${REPO_DIR}/platformio.ini"; then
  die "No agregues lvgl/lvgl a PlatformIO: LVGL pertenece a la capa ESPHome."
fi

echo "[OK] ESPHome: LVGL + GT911 + ST7701S + 480x480" | tee -a "${LOG_FILE}"
echo "[OK] PlatformIO: GFX 1.5.9 + Wire/GT911 + WiFi + HTTPClient" | tee -a "${LOG_FILE}"
echo "[OK] 3C commandBuffer + API + polling 2.5 s" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# REAL CREDENTIALS
# ------------------------------------------------------------

[[ -f "${SECRETS}" ]] || die "Falta src/secrets.yaml para flash real."
for key in wifi_ssid wifi_password display_key display_ota; do
  grep -Eq "^[[:space:]]*${key}:[[:space:]]*.+$" "${SECRETS}" ||     die "Falta o está vacío '${key}' en src/secrets.yaml."
done
[[ -f "${LOCAL_CONFIG}" ]] || die "Falta include/local_config.h para PlatformIO."

# ------------------------------------------------------------
# COMPILE BOTH LAYERS
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo " COMPILE BOTH FIRMWARE LAYERS" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"

set +e
BUILD_MODE=real BUILD_PLATFORMIO=1 SKIP_GIT_UPDATE=1 REPO_DIR="${REPO_DIR}" PROJECT_BASE="${REPO_DIR}" "${REPO_DIR}/scripts/02_pull_build_guition.sh" 2>&1 | tee -a "${LOG_FILE}"
BUILD_RC=${PIPESTATUS[0]}
set -e

[[ "${BUILD_RC}" -eq 0 ]] ||   die "BLOCK 2 falló al compilar ambas capas. Exit=${BUILD_RC}. Consulte ${BUILD_LOG}."

PIO_BUILD_DIR="${REPO_DIR}/.pio/build/${PIO_ENV}"
[[ -f "${PIO_BUILD_DIR}/firmware.bin" ]] ||   die "Falta artifact PlatformIO: ${PIO_BUILD_DIR}/firmware.bin"

ESPHOME_BIN="$(find "${REPO_DIR}/.esphome/build" -type f -name firmware.bin -print -quit 2>/dev/null || true)"
[[ -n "${ESPHOME_BIN}" ]] ||   die "No se encontró firmware.bin de ESPHome."

echo "[OK] ESPHome artifact : ${ESPHOME_BIN}" | tee -a "${LOG_FILE}"
echo "[OK] PlatformIO artifact: ${PIO_BUILD_DIR}/firmware.bin" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# PORT DETECTION
# ------------------------------------------------------------

detect_port() {
  local count
  count="$(find /dev -maxdepth 1 -type c \( -name 'ttyACM*' -o -name 'ttyUSB*' \) -print 2>/dev/null | wc -l)"

  if [[ "${count}" -eq 1 ]]; then
    find /dev -maxdepth 1 -type c \( -name 'ttyACM*' -o -name 'ttyUSB*' \) -print 2>/dev/null | sort | head -n1
    return 0
  fi

  if [[ "${count}" -gt 1 ]]; then
    echo "[ERROR] Hay varios puertos serie:" >&2
    find /dev -maxdepth 1 -type c \( -name 'ttyACM*' -o -name 'ttyUSB*' \) -print 2>/dev/null | sort >&2
  else
    echo "[ERROR] No se detectó /dev/ttyACM* ni /dev/ttyUSB*." >&2
  fi
  return 1
}

if [[ -z "${PORT}" ]]; then
  PORT="$(detect_port)" || {
    echo
    echo "Diagnóstico:"
    pio device list || true
    ls -l /dev/ttyACM* /dev/ttyUSB* 2>/dev/null || true
    exit 20
  }
fi

[[ -e "${PORT}" ]] || die "El puerto no existe: ${PORT}"
[[ -r "${PORT}" && -w "${PORT}" ]] || die "Sin permisos de lectura/escritura: ${PORT}"

echo "[OK] PORT=${PORT}" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# FLASH ONE SELECTED LAYER
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo " FLASH | ${LAYER}" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"

set +e
if [[ "${LAYER}" == "platformio" ]]; then
  pio run     --environment "${PIO_ENV}"     --target upload     --upload-port "${PORT}" 2>&1 | tee -a "${LOG_FILE}"
  FLASH_RC=${PIPESTATUS[0]}
else
  esphome upload     "${CONFIG}"     --device "${PORT}" 2>&1 | tee -a "${LOG_FILE}"
  FLASH_RC=${PIPESTATUS[0]}
fi
set -e

[[ "${FLASH_RC}" -eq 0 ]] || die "Flash de ${LAYER} falló (exit ${FLASH_RC})."
echo "[OK] FLASH COMPLETADO: ${LAYER}" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# RE-DISCOVER PORT AFTER RESET
# ------------------------------------------------------------

sleep 3

if [[ ! -e "${PORT}" ]]; then
  NEW_PORT="$(detect_port || true)"
  if [[ -n "${NEW_PORT}" ]]; then
    PORT="${NEW_PORT}"
  fi
fi

echo | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo " SERIAL BOOT MONITOR" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo "Layer: ${LAYER}" | tee -a "${LOG_FILE}"
echo "Port : ${PORT}" | tee -a "${LOG_FILE}"
echo "Baud : ${BAUD}" | tee -a "${LOG_FILE}"

if [[ "${OPEN_MONITOR}" != "true" ]]; then
  echo "[INFO] Monitor desactivado." | tee -a "${LOG_FILE}"
  exit 0
fi

set +e
if [[ "${LAYER}" == "platformio" ]]; then
  pio device monitor --port "${PORT}" --baud "${BAUD}" 2>&1 | tee -a "${LOG_FILE}"
else
  esphome logs "${CONFIG}" --device "${PORT}" 2>&1 | tee -a "${LOG_FILE}"
fi
MONITOR_RC=${PIPESTATUS[0]}
set -e

echo | tee -a "${LOG_FILE}"
echo "Monitor exit code: ${MONITOR_RC}" | tee -a "${LOG_FILE}"
echo "Evidence log     : ${LOG_FILE}" | tee -a "${LOG_FILE}"
echo
echo "[INFO] Ambas capas fueron compiladas." | tee -a "${LOG_FILE}"
echo "[INFO] Solo '${LAYER}' fue flasheada." | tee -a "${LOG_FILE}"

exit 0
