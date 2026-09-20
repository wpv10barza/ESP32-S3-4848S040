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

if [[ -z "${PORT}" ]]; then
  PORT="$(find /dev -maxdepth 1 -type c \( -name 'ttyACM*' -o -name 'ttyUSB*' \) -print 2>/dev/null | sort | head -n 1)"
fi

[[ -n "${PORT}" && -e "${PORT}" ]] || {
  echo "[ERROR] ESP32 serial port not found. Use PORT=/dev/ttyACM0."
  pio device list || true
  exit 20
}

[[ -f ".pio/build/${PIO_ENV}/firmware.bin" ]] || {
  echo "[ERROR] Run BLOCK 5 first."; exit 1;
}

pio run -e "${PIO_ENV}" -t upload --upload-port "${PORT}"
printf '\n[OK] BLOCK 6 — flashed ${PIO_ENV} on ${PORT}.\n'

if [[ "${MONITOR}" == "1" ]]; then
  pio device monitor --port "${PORT}" --baud "${BAUD}"
fi
