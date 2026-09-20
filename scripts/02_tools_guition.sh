#!/usr/bin/env bash
set -Eeuo pipefail

# BLOCK 2 — install exact Python tools; safe to resume.
REPO_DIR="${REPO_DIR:-${HOME}/project/ESP32-S3-4848S040}"
VENV_DIR="${REPO_DIR}/.venv"
ESPHOME_VERSION="${ESPHOME_VERSION:-2026.8.2}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION:-6.2.0}"

cd "${REPO_DIR}"
[[ -d .git ]] || { echo "[ERROR] Run BLOCK 1 first."; exit 1; }

PYTHON_BIN="${PYTHON_BIN:-python3}"
"${PYTHON_BIN}" -c 'import sys; assert (3,12) <= sys.version_info < (3,15), sys.version'

if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
fi

source "${VENV_DIR}/bin/activate"
python -m pip install --upgrade pip
python -m pip install "esphome==${ESPHOME_VERSION}" "platformio==${PLATFORMIO_VERSION}"

[[ "$(esphome version)" == *"${ESPHOME_VERSION}"* ]] || {
  echo "[ERROR] ESPHome version mismatch."; exit 2;
}
pio --version | grep -Fq "6.2.0" || {
  echo "[ERROR] PlatformIO version mismatch."; exit 2;
}

printf '\n[OK] BLOCK 2 — ESPHome %s | PlatformIO %s\n' "${ESPHOME_VERSION}" "${PLATFORMIO_VERSION}"
