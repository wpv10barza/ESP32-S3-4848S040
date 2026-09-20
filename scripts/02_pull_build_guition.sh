#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# GUITION ESP32-S3-4848S040
# BLOCK 2 | PULL / CONFIG / COMPILE
#
# Architecture:
#   ESPHome -> LVGL + GT911 + ST7701S + 480x480
#   PlatformIO -> 3C firmware + Arduino-GFX + WiFi + HTTP + Wire
# ============================================================

PROJECT_BASE="${PROJECT_BASE:-${HOME}/project}"
REPO_DIR="${REPO_DIR:-${PROJECT_BASE}/COPIA2}"

# Always build the merged repository, not the upstream Guition repository.
REPO_URL="${REPO_URL:-https://github.com/wpv10barza/ESP32-S3-4848S040.git}"
REPO_REF="${REPO_REF:-main}"

VENV_DIR="${REPO_DIR}/.venv"

ESPHOME_VERSION="${ESPHOME_VERSION:-2026.8.2}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION:-6.2.0}"

CONFIG="${REPO_DIR}/src/main.yaml"
SECRETS="${REPO_DIR}/src/secrets.yaml"

LOG_DIR="${REPO_DIR}/.ci"
LOG_FILE="${LOG_DIR}/build.log"

# 0 = real local build requires src/secrets.yaml.
# 1 = create temporary dummy secrets only for syntax/compile validation.
ALLOW_DUMMY_SECRETS="${ALLOW_DUMMY_SECRETS:-0}"

# 1 = also build the independent PlatformIO 3C firmware.
BUILD_PLATFORMIO="${BUILD_PLATFORMIO:-1}"

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
    echo "============================================================" | tee -a "${LOG_FILE}"
    echo "Build log: ${LOG_FILE}" | tee -a "${LOG_FILE}"
    exit "${rc}"
}
trap on_error ERR

die() {
    echo "[ERROR] $*" | tee -a "${LOG_FILE}" >&2
    exit 1
}

cleanup_dummy_secrets() {
    if [ "${DUMMY_CREATED:-0}" = "1" ] && [ -f "${SECRETS}" ]; then
        rm -f "${SECRETS}"
        echo "[OK] Temporary dummy src/secrets.yaml removed." | tee -a "${LOG_FILE}"
    fi
}
trap cleanup_dummy_secrets EXIT

echo "============================================================" | tee "${LOG_FILE}"
echo " GUITION ESP32-S3-4848S040" | tee -a "${LOG_FILE}"
echo " BLOCK 2 | PULL / CONFIG / COMPILE" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# VERIFY REPOSITORY
# ------------------------------------------------------------

[ -d "${REPO_DIR}/.git" ] || {
    echo "[ERROR] Repository not found: ${REPO_DIR}" | tee -a "${LOG_FILE}"
    echo "Run BLOCK 1 first." | tee -a "${LOG_FILE}"
    exit 1
}

cd "${REPO_DIR}"

[ -d "${VENV_DIR}" ] || {
    echo "[ERROR] .venv not found. Run BLOCK 1 first." | tee -a "${LOG_FILE}"
    exit 1
}

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

# ------------------------------------------------------------
# VERIFY REMOTE
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== VERIFY REMOTE ===" | tee -a "${LOG_FILE}"

CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null || true)"

[ "${CURRENT_REMOTE}" = "${REPO_URL}" ] || {
    echo "[ERROR] origin is:" | tee -a "${LOG_FILE}"
    echo "  ${CURRENT_REMOTE:-<none>}" | tee -a "${LOG_FILE}"
    echo "[ERROR] expected:" | tee -a "${LOG_FILE}"
    echo "  ${REPO_URL}" | tee -a "${LOG_FILE}"
    echo | tee -a "${LOG_FILE}"
    echo "Fix with:" | tee -a "${LOG_FILE}"
    echo "  git remote set-url origin ${REPO_URL}" | tee -a "${LOG_FILE}"
    exit 2
}

echo "[OK] origin -> ${REPO_URL}" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# PULL MAIN SAFELY
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== FETCH/PULL ===" | tee -a "${LOG_FILE}"

git fetch --prune --tags origin

git checkout "${REPO_REF}" >/dev/null 2>&1 ||     die "Could not checkout ${REPO_REF}."

# Never destroy local work automatically.
if ! git diff --quiet || ! git diff --cached --quiet; then
    die "Working tree has local changes. Commit/stash them before BLOCK 2."
fi

git pull --ff-only origin "${REPO_REF}"

# ------------------------------------------------------------
# VERIFY REVISION
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== REVISION ===" | tee -a "${LOG_FILE}"

git remote -v | tee -a "${LOG_FILE}"
git branch --show-current | tee -a "${LOG_FILE}"
git log -1 --oneline --decorate | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# VERIFY FILES
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
echo "=== VERIFY ESPHOME UI LIBRARIES ===" | tee -a "${LOG_FILE}"

grep -q '^lvgl:' "${CONFIG}" || die "LVGL is not declared in src/main.yaml."
grep -q 'platform: gt911' "${CONFIG}" || die "GT911 is not declared in src/main.yaml."
grep -q 'platform: st7701s' "${CONFIG}" || die "ST7701S is not declared in src/main.yaml."
grep -q 'width: 480' "${CONFIG}" || die "480px width is missing."
grep -q 'height: 480' "${CONFIG}" || die "480px height is missing."

echo "[OK] ESPHome LVGL" | tee -a "${LOG_FILE}"
echo "[OK] ESPHome GT911" | tee -a "${LOG_FILE}"
echo "[OK] ESPHome ST7701S" | tee -a "${LOG_FILE}"
echo "[OK] ESPHome 480x480" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# VERIFY PLATFORMIO COMPONENT REFERENCES
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== VERIFY PLATFORMIO 3C LIBRARIES ===" | tee -a "${LOG_FILE}"

grep -Fq     'moononournation/GFX Library for Arduino@1.5.9'     "${REPO_DIR}/platformio.ini" ||     die "GFX Library for Arduino 1.5.9 is not declared."

for include in     '#include <Arduino_GFX_Library.h>'     '#include <WiFi.h>'     '#include <HTTPClient.h>'     '#include <Wire.h>'
do
    grep -Fq "${include}"         "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||         die "Missing firmware dependency reference: ${include}"
done

grep -Fq 'kTouchAddress = 0x5D'     "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||     die "GT911 I2C address 0x5D is missing."

grep -Fq 'kScreenWidth = 480'     "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||     die "3C firmware width=480 is missing."

grep -Fq 'kScreenHeight = 480'     "${REPO_DIR}/platformio/src/panel_4848s040/main.cpp" ||     die "3C firmware height=480 is missing."

echo "[OK] Arduino-GFX 1.5.9" | tee -a "${LOG_FILE}"
echo "[OK] WiFi" | tee -a "${LOG_FILE}"
echo "[OK] HTTPClient" | tee -a "${LOG_FILE}"
echo "[OK] Wire" | tee -a "${LOG_FILE}"
echo "[OK] GT911 I2C 0x5D" | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# ESPHOME SECRETS
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== ESPHOME SECRETS ===" | tee -a "${LOG_FILE}"

DUMMY_CREATED=0

if [ ! -f "${SECRETS}" ]; then
    if [ "${ALLOW_DUMMY_SECRETS}" != "1" ]; then
        echo "[ERROR] Missing ${SECRETS}" | tee -a "${LOG_FILE}"
        echo "For a real device build, create it from:" | tee -a "${LOG_FILE}"
        echo "  cp src/secrets.yaml.example src/secrets.yaml" | tee -a "${LOG_FILE}"
        echo "and fill in Wi-Fi/API/OTA values." | tee -a "${LOG_FILE}"
        echo | tee -a "${LOG_FILE}"
        echo "For validation only, use:" | tee -a "${LOG_FILE}"
        echo "  ALLOW_DUMMY_SECRETS=1 ./02_pull_build_guition.sh" | tee -a "${LOG_FILE}"
        exit 3
    fi

    echo "[WARN] Creating temporary dummy secrets for validation only." | tee -a "${LOG_FILE}"

    DUMMY_KEY="$(python - <<'PY'
import base64
print(base64.b64encode(b'0123456789abcdef0123456789abcdef').decode())
PY
)"

    cat > "${SECRETS}" <<EOF
wifi_ssid: "CI_DUMMY_WIFI"
wifi_password: "CI_DUMMY_PASSWORD"
display_key: "${DUMMY_KEY}"
display_ota: "CI_DUMMY_OTA"
EOF

    DUMMY_CREATED=1
else
    echo "[OK] ${SECRETS}" | tee -a "${LOG_FILE}"
fi

# ------------------------------------------------------------
# ESPHOME VERSION
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== ESPHOME ===" | tee -a "${LOG_FILE}"

esphome version | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# ESPHOME CONFIG
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo " ESPHOME CONFIG VALIDATION" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"

esphome config "${CONFIG}" 2>&1 | tee -a "${LOG_FILE}"

# ------------------------------------------------------------
# ESPHOME COMPILE
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo " ESPHOME COMPILE | LVGL + GT911 + ST7701S + 480x480" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"

esphome compile "${CONFIG}" 2>&1 | tee -a "${LOG_FILE}"

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
fi

# ------------------------------------------------------------
# BUILD OUTPUTS
# ------------------------------------------------------------

echo | tee -a "${LOG_FILE}"
echo "=== BUILD OUTPUTS ===" | tee -a "${LOG_FILE}"

ESPHOME_BUILD_DIR="${REPO_DIR}/.esphome/build"

if [ -d "${ESPHOME_BUILD_DIR}" ]; then
    echo "[OK] ESPHome build directory exists." | tee -a "${LOG_FILE}"
    find "${ESPHOME_BUILD_DIR}"         -maxdepth 5         -type f         \( -name "*.bin" -o -name "*.elf" \)         -print 2>/dev/null | tee -a "${LOG_FILE}" || true
fi

PIO_BUILD_DIR="${REPO_DIR}/.pio/build/panel_4848s040"

if [ -d "${PIO_BUILD_DIR}" ]; then
    echo "[OK] PlatformIO build directory exists." | tee -a "${LOG_FILE}"
    find "${PIO_BUILD_DIR}"         -maxdepth 3         -type f         \( -name "*.bin" -o -name "*.elf" \)         -print 2>/dev/null | tee -a "${LOG_FILE}" || true
fi

# ------------------------------------------------------------
# BUILD STATUS
# ------------------------------------------------------------

if [ "${DUMMY_CREATED}" = "1" ]; then
    echo | tee -a "${LOG_FILE}"
    echo "[WARN] Build completed with temporary dummy ESPHome secrets." | tee -a "${LOG_FILE}"
    echo "[WARN] DO NOT flash this artifact as a production device." | tee -a "${LOG_FILE}"
fi

echo | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"
echo " BLOCK 2 SUCCESS" | tee -a "${LOG_FILE}"
echo "============================================================" | tee -a "${LOG_FILE}"

echo
echo "Repository:"
echo "  ${REPO_DIR}"

echo
echo "ESPHome UI:"
echo "  LVGL + GT911 + ST7701S + 480x480"

echo
echo "PlatformIO 3C:"
echo "  Arduino-GFX + WiFi + HTTPClient + Wire"

echo
echo "Log:"
echo "  ${LOG_FILE}"

echo
echo "Next:"
echo "  ./03_flash_monitor_guition.sh"
