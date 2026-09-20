#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# GUITION ESP32-S3-4848S040
# BLOCK 2 | PULL / CONFIG / COMPILE
#
# src/main.yaml is ESPHome and contains !secret references.
#
# BUILD_MODE=real
#   - requires src/secrets.yaml
#   - compiles the real ESPHome configuration
#
# BUILD_MODE=validate
#   - copies src/ to a temporary isolated directory
#   - generates temporary CI-only secrets.yaml
#   - validates + compiles the copied configuration
#   - NEVER modifies or flashes with the user's real secrets
#
# PlatformIO 3C is independent of ESPHome secrets.
# ============================================================

PROJECT_BASE="${PROJECT_BASE:-${HOME}/project}"
REPO_DIR="${REPO_DIR:-${PROJECT_BASE}/COPIA2}"

REPO_URL="${REPO_URL:-https://github.com/wpv10barza/ESP32-S3-4848S040.git}"
REPO_REF="${REPO_REF:-main}"

VENV_DIR="${REPO_DIR}/.venv"
ESPHOME_VERSION="${ESPHOME_VERSION:-2026.8.2}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION:-6.2.0}"

CONFIG="${REPO_DIR}/src/main.yaml"
REAL_SECRETS="${REPO_DIR}/src/secrets.yaml"

LOG_DIR="${REPO_DIR}/.ci"
LOG_FILE="${LOG_DIR}/build.log"

BUILD_MODE="${BUILD_MODE:-real}"
BUILD_PLATFORMIO="${BUILD_PLATFORMIO:-1}"
SKIP_GIT_UPDATE="${SKIP_GIT_UPDATE:-0}"

case "${BUILD_MODE}" in
  real|validate) ;;
  *)
    echo "[ERROR] BUILD_MODE debe ser 'real' o 'validate'." >&2
    exit 64
    ;;
esac

mkdir -p "${LOG_DIR}"

on_error() {
    local rc=$?
    echo
    echo "============================================================" | tee -a "${LOG_FILE}"
    echo "[ERROR] BLOCK 2 FAILED" | tee -a "${LOG_FILE}"
    echo "Exit code : ${rc}" | tee -a "${LOG_FILE}"
    echo "Line      : ${BASH_LINENO[0]:-unknown}" | tee -a "${LOG_FILE}"
    echo "Command   : ${BASH_COMMAND:-unknown}" | tee -a "${LOG_FILE}"
    echo "PWD       : $(pwd)" | tee -a "${LOG_FILE}"
    echo "Mode      : ${BUILD_MODE}" | tee -a "${LOG_FILE}"
    echo "============================================================" | tee -a "${LOG_FILE}"
    echo "Build log: ${LOG_FILE}" | tee -a "${LOG_FILE}"
    exit "${rc}"
}
trap on_error ERR

die() {
    echo "[ERROR] $*" | tee -a "${LOG_FILE}" >&2
    exit 1
}

TMP_ESPHOME_DIR=""
cleanup() {
    if [ -n "${TMP_ESPHOME_DIR}" ] && [ -d "${TMP_ESPHOME_DIR}" ]; then
        rm -rf "${TMP_ESPHOME_DIR}"
        echo "[OK] Temporary ESPHome validation directory removed." | tee -a "${LOG_FILE}"
    fi
}
trap cleanup EXIT

echo "============================================================" | tee "${LOG_FILE}"
echo " GUITION ESP32-S3-4848S040" | tee -a "${LOG_FILE}"
echo " BLOCK 2 | PULL / CONFIG / COMPILE" | tee -a "${LOG_FILE}"
echo " Mode     : ${BUILD_MODE}" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"

[ -d "${REPO_DIR}/.git" ] || {
    echo "[ERROR] Repository not found: ${REPO_DIR}" | tee -a "${LOG_FILE}"
    echo "Run BLOCK 1 first." | tee -a "${LOG_FILE}"
    exit 1
}

cd "${REPO_DIR}"

# ------------------------------------------------------------
# PYTHON ENVIRONMENT
# ------------------------------------------------------------

if [ ! -d "${VENV_DIR}" ]; then
    if [ "${CI:-false}" = "true" ]; then
        echo "[INFO] CI mode: creating isolated venv for BLOCK 2." | tee -a "${LOG_FILE}"
        python3 -m venv "${VENV_DIR}"
    else
        die ".venv not found. Run BLOCK 1 first."
    fi
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python -m pip install --disable-pip-version-check --upgrade pip setuptools wheel >/dev/null

if ! command -v esphome >/dev/null 2>&1; then
    python -m pip install --disable-pip-version-check "esphome==${ESPHOME_VERSION}"
fi

if [ "${BUILD_PLATFORMIO}" = "1" ] && ! command -v pio >/dev/null 2>&1; then
    python -m pip install --disable-pip-version-check "platformio==${PLATFORMIO_VERSION}"
fi

# ------------------------------------------------------------
# VERIFY REMOTE / UPDATE
# ------------------------------------------------------------

if [ "${SKIP_GIT_UPDATE}" != "1" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "=== VERIFY REMOTE ===" | tee -a "${LOG_FILE}"

    CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null || true)"
    [ "${CURRENT_REMOTE}" = "${REPO_URL}" ] || {
        echo "[ERROR] origin is:" | tee -a "${LOG_FILE}"
        echo "  ${CURRENT_REMOTE:-<none>}" | tee -a "${LOG_FILE}"
        echo "[ERROR] expected:" | tee -a "${LOG_FILE}"
        echo "  ${REPO_URL}" | tee -a "${LOG_FILE}"
        exit 2
    }

    git fetch --prune --tags origin
    git checkout "${REPO_REF}" >/dev/null 2>&1 || die "Could not checkout ${REPO_REF}."

    if ! git diff --quiet || ! git diff --cached --quiet; then
        die "Working tree has local changes. Commit/stash them before BLOCK 2."
    fi

    git pull --ff-only origin "${REPO_REF}"
else
    echo "[INFO] SKIP_GIT_UPDATE=1: using the checked-out CI workspace." | tee -a "${LOG_FILE}"
fi

echo | tee -a "${LOG_FILE}"
echo "=== REVISION ===" | tee -a "${LOG_FILE}"
git remote -v | tee -a "${LOG_FILE}"
git branch --show-current | tee -a "${LOG_FILE}" || true
git log -1 --oneline --decorate | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# VERIFY PROJECT
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== VERIFY PROJECT ===" | tee -a "${LOG_FILE}"

required_files=(
    "${CONFIG}"
    "${REPO_DIR}/platformio.ini"
    "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp"
    "${REPO_DIR}/include/command_buffer.h"
    "${REPO_DIR}/include/virtual_keyboard.h"
)

for path in "${required_files[@]}"; do
    [ -f "${path}" ] || die "Missing: ${path}"
    echo "[OK] ${path}" | tee -a "${LOG_FILE}"
done

# ------------------------------------------------------------
# VERIFY ESPHOME COMPONENT REFERENCES
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== VERIFY ESPHOME UI REFERENCES ===" | tee -a "${LOG_FILE}"

grep -q '^lvgl:' "${CONFIG}" || die "LVGL missing."
grep -q 'platform: gt911' "${CONFIG}" || die "GT911 missing."
grep -q 'platform: st7701s' "${CONFIG}" || die "ST7701S missing."
grep -q 'width: 480' "${CONFIG}" || die "480px width missing."
grep -q 'height: 480' "${CONFIG}" || die "480px height missing."
grep -q '!secret wifi_ssid' "${CONFIG}" || die "!secret wifi_ssid missing."
grep -q '!secret wifi_password' "${CONFIG}" || die "!secret wifi_password missing."
grep -q '!secret display_key' "${CONFIG}" || die "!secret display_key missing."
grep -q '!secret display_ota' "${CONFIG}" || die "!secret display_ota missing."

echo "[OK] ESPHome LVGL / GT911 / ST7701S / 480x480 / !secret" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# VERIFY PLATFORMIO REFERENCES
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== VERIFY PLATFORMIO 3C REFERENCES ===" | tee -a "${LOG_FILE}"

grep -Fq 'moononournation/GFX Library for Arduino@1.5.9' "${REPO_DIR}/platformio.ini" ||     die "GFX Library for Arduino 1.5.9 is missing."

for include in     '#include <Arduino_GFX_Library.h>'     '#include <WiFi.h>'     '#include <HTTPClient.h>'     '#include <Wire.h>'
do
    grep -Fq "${include}" "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||         die "Missing firmware dependency reference: ${include}"
done

grep -Fq 'kTouchAddress = 0x5D' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||     die "GT911 I2C address 0x5D is missing."
grep -Fq 'kScreenWidth = 480' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||     die "3C firmware width=480 is missing."
grep -Fq 'kScreenHeight = 480' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||     die "3C firmware height=480 is missing."
grep -Fq 'commandBuffer' "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||     die "commandBuffer is missing."

echo "[OK] PlatformIO 3C dependencies" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# SELECT ESPHOME SECRET MODE
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== ESPHOME SECRET MODE ===" | tee -a "${LOG_FILE}"

ESPHOME_CONFIG="${CONFIG}"

if [ "${BUILD_MODE}" = "real" ]; then
    echo "[MODE] REAL BUILD WITH LOCAL CREDENTIALS" | tee -a "${LOG_FILE}"

    [ -f "${REAL_SECRETS}" ] || {
        echo "[ERROR] Missing ${REAL_SECRETS}" | tee -a "${LOG_FILE}"
        echo "Create it locally from:" | tee -a "${LOG_FILE}"
        echo "  cp src/secrets.yaml.example src/secrets.yaml" | tee -a "${LOG_FILE}"
        echo "Then fill wifi_ssid, wifi_password, display_key and display_ota." | tee -a "${LOG_FILE}"
        exit 3
    }

    for key in wifi_ssid wifi_password display_key display_ota; do
        grep -Eq "^[[:space:]]*${key}:[[:space:]]*.+$" "${REAL_SECRETS}" ||             die "Missing or empty key in src/secrets.yaml: ${key}"
    done

    echo "[OK] src/secrets.yaml present; secret values are not printed." | tee -a "${LOG_FILE}"
else
    echo "[MODE] VALIDATION WITH TEMPORARY SECRETS" | tee -a "${LOG_FILE}"

    TMP_ESPHOME_DIR="$(mktemp -d "${LOG_DIR}/esphome-validate.XXXXXX")"
    cp -a "${REPO_DIR}/src/." "${TMP_ESPHOME_DIR}/"
    rm -f "${TMP_ESPHOME_DIR}/secrets.yaml"
    rm -rf "${TMP_ESPHOME_DIR}/.esphome"

    DUMMY_KEY="$(python - <<'PY'
import base64
print(base64.b64encode(b'0123456789abcdef0123456789abcdef').decode())
PY
)"

    cat > "${TMP_ESPHOME_DIR}/secrets.yaml" <<EOF
wifi_ssid: "CI_DUMMY_WIFI"
wifi_password: "CI_DUMMY_PASSWORD"
display_key: "${DUMMY_KEY}"
display_ota: "CI_DUMMY_OTA"
EOF

    ESPHOME_CONFIG="${TMP_ESPHOME_DIR}/main.yaml"

    echo "[OK] Temporary ESPHome workspace created outside the real src/ tree." | tee -a "${LOG_FILE}"
    echo "[OK] Temporary secrets generated; real credentials are untouched." | tee -a "${LOG_FILE}"
fi

# ------------------------------------------------------------
# ESPHOME VERSION / CONFIG / COMPILE
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== ESPHOME ===" | tee -a "${LOG_FILE}"
esphome version | tee -a "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo " ESPHOME CONFIG VALIDATION" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"

esphome config "${ESPHOME_CONFIG}" 2>&1 | tee -a "${LOG_FILE}"

echo | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo " ESPHOME COMPILE | LVGL + GT911 + ST7701S + 480x480" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"

esphome compile "${ESPHOME_CONFIG}" 2>&1 | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# PLATFORMIO PACKAGE RESOLUTION + BUILD
# ------------------------------------------------------------

if [ "${BUILD_PLATFORMIO}" = "1" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "============================================================" | tee -a "${LOG_FILE}"
    echo " PLATFORMIO 3C BUILD | ARDUINO-GFX + GT911 + API" | tee -a "${LOG_FILE}"
    echo "============================================================" | tee -a "${LOG_FILE}"

    pio pkg install --environment panel_4848s040 2>&1 | tee -a "${LOG_FILE}"
    pio run --environment panel_4848s040 2>&1 | tee -a "${LOG_FILE}"
else
    echo | tee -a "${LOG_FILE}"
    echo "[INFO] BUILD_PLATFORMIO=0: PlatformIO build skipped." | tee -a "${LOG_FILE}"
fi

# ------------------------------------------------------------
# BUILD STATUS
# ------------------------------------------------------------

if [ "${BUILD_MODE}" = "validate" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "[WARN] ESPHome build used temporary dummy secrets only." | tee -a "${LOG_FILE}"
    echo "[WARN] This validation artifact must NOT be flashed as a real device." | tee -a "${LOG_FILE}"
else
    echo | tee -a "${LOG_FILE}"
    echo "[OK] ESPHome build used the user's local real credentials." | tee -a "${LOG_FILE}"
fi

echo | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo " BLOCK 2 SUCCESS" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"

echo
echo "Mode:"
echo "  ${BUILD_MODE}"
echo
echo "Log:"
echo "  ${LOG_FILE}"
echo
echo "Next:"
echo "  ./scripts/flash-panel.sh"
echo
