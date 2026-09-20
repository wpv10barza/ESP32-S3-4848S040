#!/usr/bin/env bash
set -Eeuo pipefail

# BLOCK 6 — flash and monitor physical ESP32-S3.
REPO_DIR="${REPO_DIR:-${HOME}/project/ESP32-S3-4848S040}"
VENV_DIR="${REPO_DIR}/.venv"
PIO_ENV="${PIO_ENV:-panel_4848s040}"
PORT="${PORT:-}"
BAUD="${BAUD:-115200}"
MONITOR="${MONITOR:-1}"

cd "${REPO_DIR}"
source "${VENV_DIR}/bin/activate"

discover_port() {
  local p
  # Prefer stable udev symlinks, then common USB serial device names.
  for p in /dev/serial/by-id/* /dev/ttyACM* /dev/ttyUSB*; do
    [[ -c "$p" ]] || continue
    printf '%s\n' "$p"
    return 0
  done
  return 1
}

show_port_diagnostics() {
  echo "[INFO] PlatformIO-visible devices:"
  pio device list || true
  echo
  echo "[INFO] Linux USB serial candidates:"
  ls -l /dev/serial/by-id/* /dev/ttyACM* /dev/ttyUSB* 2>/dev/null || true

  if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
    echo
    echo "[INFO] WSL detected."
    echo "[INFO] Attach the ESP32 USB device to WSL2, then verify with:"
    echo "       usbipd list              # PowerShell"
    echo "       lsusb                    # WSL"
    echo "       ls -l /dev/ttyACM* /dev/ttyUSB*"
  fi
}

if [[ -n "${PLATFORMIO_UPLOAD_PORT:-}" && -z "${PORT}" ]]; then
  echo "[ERROR] PLATFORMIO_UPLOAD_PORT is set to '${PLATFORMIO_UPLOAD_PORT}'."
  echo "[ERROR] This script requires PORT=... explicitly or automatic USB discovery."
  echo "[ERROR] Refusing hidden global-port overrides so /dev/ttyS0 cannot be selected accidentally."
  show_port_diagnostics
  exit 21
fi

if [[ -n "${PORT}" ]]; then
  case "${PORT}" in
    /dev/ttyS*)
      echo "[ERROR] Invalid ESP32 USB port: ${PORT}"
      echo "[ERROR] Do not use legacy /dev/ttyS* for this WSL physical-flash flow."
      echo "[ERROR] Use /dev/serial/by-id/... or /dev/ttyACM0 (or /dev/ttyUSB0) after USB attachment."
      show_port_diagnostics
      exit 20
      ;;
  esac
else
  PORT="$(discover_port || true)"
fi

[[ -n "${PORT}" && -c "${PORT}" ]] || {
  echo "[ERROR] ESP32 serial port not found."
  echo "[ERROR] Expected /dev/serial/by-id/*, /dev/ttyACM*, or /dev/ttyUSB*."
  show_port_diagnostics
  exit 20
}

[[ -f ".pio/build/${PIO_ENV}/firmware.bin" ]] || {
  echo "[ERROR] Run BLOCK 5 first."; exit 1;
}

echo "[INFO] Flash target: ${PORT}"
pio run -e "${PIO_ENV}" -t upload --upload-port "${PORT}"
printf '\n[OK] BLOCK 6 — flashed ${PIO_ENV} on ${PORT}.\n'

if [[ "${MONITOR}" == "1" ]]; then
  pio device monitor --port "${PORT}" --baud "${BAUD}"
fi
