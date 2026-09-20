#!/usr/bin/env bash
set -Eeuo pipefail

# BLOCK 2 — Python venv + exact tool versions.
# Safe to re-run after an interrupted pip install.
PROJECT_BASE="${PROJECT_BASE:-${HOME}/project}"
REPO_DIR="${REPO_DIR:-${PROJECT_BASE}/ESP32-S3-4848S040}"
VENV_DIR="${REPO_DIR}/.venv"
ESPHOME_VERSION="${ESPHOME_VERSION:-2026.8.2}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION:-6.2.0}"

cd "${REPO_DIR}"
[[ -d .git ]] || { echo "[ERROR] Run BLOCK 1 first."; exit 1; }

PYTHON_BIN="${PYTHON_BIN:-python3}"
"${PYTHON_BIN}" -c 'import sys; assert sys.version_info >= (3,12) and sys.version_info < (3,15), sys'

if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python -m pip install "esphome==${ESPHOME_VERSION}"
python -m pip install "platformio==${PLATFORMIO_VERSION}"

printf '\n[OK] BLOCK 2\nESPHome: %s\nPlatformIO: %s\n' "$(esphome version)" "$(pio --version)"
