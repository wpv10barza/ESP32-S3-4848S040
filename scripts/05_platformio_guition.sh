#!/usr/bin/env bash
set -Eeuo pipefail

# BLOCK 5 — native regression checks + ESP32-S3 panel build.
PROJECT_BASE="${PROJECT_BASE:-${HOME}/project}"
REPO_DIR="${REPO_DIR:-${PROJECT_BASE}/ESP32-S3-4848S040}"
VENV_DIR="${REPO_DIR}/.venv"

cd "${REPO_DIR}"
[[ -f "${VENV_DIR}/bin/activate" ]] || { echo "[ERROR] Run BLOCK 2 first."; exit 1; }
source "${VENV_DIR}/bin/activate"
command -v pio >/dev/null || { echo "[ERROR] PlatformIO missing."; exit 1; }

mkdir -p .ci/bin

g++ -std=c++17 -Wall -Wextra -Werror -Iinclude tests/test_command_buffer_native.cpp -o .ci/bin/command_buffer_native
.ci/bin/command_buffer_native

g++ -std=c++17 -Wall -Wextra -Werror -Iinclude test/test_command_text_viewport/test_main.cpp -o .ci/bin/command_text_viewport_test
.ci/bin/command_text_viewport_test

g++ -std=c++17 -Wall -Wextra -Werror -Iinclude test/test_virtual_keyboard/test_main.cpp -o .ci/bin/virtual_keyboard_hit_test
.ci/bin/virtual_keyboard_hit_test

python tests/test_panel_state_contract.py
python tests/test_wifi_source.py
python tests/test_command_editor_integration.py
python test/command_buffer_regression.py

pio run -e panel_4848s040

[[ -f .pio/build/panel_4848s040/firmware.bin ]] || {
  echo "[ERROR] PlatformIO firmware.bin missing."
  exit 2
}

printf '\n[OK] BLOCK 5 — native regressions, API contracts and panel_4848s040 build passed.\n'
