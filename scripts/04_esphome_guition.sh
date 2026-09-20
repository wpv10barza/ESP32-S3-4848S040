#!/usr/bin/env bash
set -Eeuo pipefail

# BLOCK 4 — ESPHome config validation + compile.
PROJECT_BASE="${PROJECT_BASE:-${HOME}/project}"
REPO_DIR="${REPO_DIR:-${PROJECT_BASE}/ESP32-S3-4848S040}"
VENV_DIR="${REPO_DIR}/.venv"
MODE="${BUILD_MODE:-validate}"

cd "${REPO_DIR}"
[[ -f "${VENV_DIR}/bin/activate" ]] || { echo "[ERROR] Run BLOCK 2 first."; exit 1; }
source "${VENV_DIR}/bin/activate"
command -v esphome >/dev/null || { echo "[ERROR] ESPHome missing."; exit 1; }

CONFIG="${REPO_DIR}/src/main.yaml"
WORK_CONFIG="${CONFIG}"
TMP_DIR=""

cleanup() { [[ -z "${TMP_DIR}" ]] || rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

case "${MODE}" in
  real)
    [[ -f "${REPO_DIR}/src/secrets.yaml" ]] || { echo "[ERROR] src/secrets.yaml missing."; exit 3; }
    ;;
  validate)
    TMP_DIR="$(mktemp -d)"
    cp -a "${REPO_DIR}/src/." "${TMP_DIR}/"
    rm -f "${TMP_DIR}/secrets.yaml"
    python - <<'PY' > "${TMP_DIR}/secrets.yaml"
import base64
key = base64.b64encode(b"0123456789abcdef0123456789abcdef").decode()
print('wifi_ssid: "CI_DUMMY_WIFI"')
print('wifi_password: "CI_DUMMY_PASSWORD"')
print(f'display_key: "{key}"')
print('display_ota: "CI_DUMMY_OTA"')
PY
    WORK_CONFIG="${TMP_DIR}/main.yaml"
    ;;
  *) echo "[ERROR] BUILD_MODE must be validate or real."; exit 64 ;;
esac

esphome config "${WORK_CONFIG}"
esphome compile "${WORK_CONFIG}"

printf '\n[OK] BLOCK 4 — ESPHome %s config + compile passed (%s mode).\n' "$(esphome version)" "${MODE}"
