#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# ESP32-S3-4848S040
# BLOCK 1 | CLONE/UPDATE + VENV + VERIFY + BUILD BOTH LAYERS
#
# Layer A: ESPHome + LVGL + ST7701S + GT911 + 480x480
# Layer B: PlatformIO + Arduino-GFX + GT911(I2C) + API + 3C
#
# Default:
#   BUILD_MODE=validate   -> ESPHome uses temporary dummy secrets
#   BUILD_PLATFORMIO=1    -> compile PlatformIO panel
#
# Real hardware build:
#   BUILD_MODE=real ./scripts/01_bootstrap_guition.sh
#
# IMPORTANT:
#   This script MUST use the merged fork:
#   https://github.com/wpv10barza/ESP32-S3-4848S040.git
#   Never clone alaltitov/Guition-ESP32-S3-4848S040 here.
# ============================================================

PROJECT_BASE="${PROJECT_BASE:-${HOME}/project}"
REPO_DIR="${REPO_DIR:-${PROJECT_BASE}/ESP32-S3-4848S040}"

REPO_URL="${REPO_URL:-https://github.com/wpv10barza/ESP32-S3-4848S040.git}"
REPO_REF="${REPO_REF:-main}"

# Pinned because this repository's i18n external component is tested
# against this ESPHome line. Do not silently upgrade to latest.
ESPHOME_VERSION="${ESPHOME_VERSION:-2026.8.2}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION:-6.2.0}"

VENV_DIR="${REPO_DIR}/.venv"
BUILD_MODE="${BUILD_MODE:-validate}"
BUILD_PLATFORMIO="${BUILD_PLATFORMIO:-1}"
RUN_BUILD="${RUN_BUILD:-1}"

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

on_error() {
    local rc=$?
    echo
    echo "============================================================"
    echo "[ERROR] BLOCK 1 FAILED"
    echo "Exit code : ${rc}"
    echo "Line      : ${BASH_LINENO[0]:-unknown}"
    echo "Command   : ${BASH_COMMAND:-unknown}"
    echo "PWD       : $(pwd)"
    echo "============================================================"
    exit "${rc}"
}
trap on_error ERR

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "$1 no está instalado."
}

case "${BUILD_MODE}" in
    validate|real) ;;
    *) die "BUILD_MODE debe ser 'validate' o 'real'." ;;
esac

case "${BUILD_PLATFORMIO}" in
    0|1) ;;
    *) die "BUILD_PLATFORMIO debe ser 0 o 1." ;;
esac

mkdir -p "${PROJECT_BASE}"

echo "============================================================"
echo " ESP32-S3-4848S040"
echo " BLOCK 1 | BOOTSTRAP + VERIFY + BUILD BOTH LAYERS"
echo "============================================================"
echo
echo "Repository : ${REPO_URL}"
echo "Ref        : ${REPO_REF}"
echo "Local dir  : ${REPO_DIR}"
echo "ESPHome    : ${ESPHOME_VERSION}"
echo "PlatformIO : ${PLATFORMIO_VERSION}"
echo "Build mode : ${BUILD_MODE}"
echo

# ------------------------------------------------------------
# REQUIREMENTS
# ------------------------------------------------------------

require_cmd git
require_cmd python3
python3 -m venv --help >/dev/null 2>&1 || die "Falta python3-venv."

# ------------------------------------------------------------
# CLONE / UPDATE THE MERGED REPOSITORY
# ------------------------------------------------------------

if [ ! -d "${REPO_DIR}/.git" ]; then
    [ ! -e "${REPO_DIR}" ] || die "Existe ${REPO_DIR}, pero no es un repositorio Git."

    echo "=== CLONANDO TU FORK MERGED ==="
    git clone --branch "${REPO_REF}" --single-branch "${REPO_URL}" "${REPO_DIR}"
else
    cd "${REPO_DIR}"

    CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null || true)"
    [ "${CURRENT_REMOTE}" = "${REPO_URL}" ] || {
        echo "[ERROR] origin actual:"
        echo "  ${CURRENT_REMOTE:-<none>}"
        echo "[ERROR] origin esperado:"
        echo "  ${REPO_URL}"
        exit 2
    }

    if ! git diff --quiet || ! git diff --cached --quiet; then
        die "Hay cambios locales. Haz commit/stash antes de actualizar."
    fi

    echo "=== ACTUALIZANDO TU FORK ==="
    git fetch --prune --tags origin
    git switch "${REPO_REF}" >/dev/null 2>&1 ||         git switch -C "${REPO_REF}" "origin/${REPO_REF}"
    git reset --hard "origin/${REPO_REF}"
fi

cd "${REPO_DIR}"

echo
echo "=== GIT ==="
git remote -v
echo
git branch --show-current
git log -1 --oneline --decorate

# ------------------------------------------------------------
# PYTHON ENVIRONMENT
# ------------------------------------------------------------

echo
echo "=== PYTHON VENV ==="

if [ ! -d "${VENV_DIR}" ]; then
    python3 -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python -m pip install     --disable-pip-version-check     --upgrade pip setuptools wheel

echo
echo "=== ESPHOME ${ESPHOME_VERSION} ==="
python -m pip install     --disable-pip-version-check     --upgrade     "esphome==${ESPHOME_VERSION}"

echo
echo "=== PLATFORMIO ${PLATFORMIO_VERSION} ==="
python -m pip install     --disable-pip-version-check     --upgrade     "platformio==${PLATFORMIO_VERSION}"

echo
echo "Python    : $(python --version)"
echo "ESPHome   : $(esphome version)"
echo "PlatformIO: $(pio --version)"

# ------------------------------------------------------------
# VERIFY MERGED REPOSITORY
# ------------------------------------------------------------

echo
echo "=== VERIFY REPOSITORY ==="

required_files=(
    "README.md"
    "src/main.yaml"
    "platformio.ini"
    "platformio/src/panel_4848s040/main.cpp"
    "include/command_buffer.h"
    "include/virtual_keyboard.h"
    "contract/device-command-v1.json"
    "backend/device_api.py"
    ".github/workflows/ci.yml"
    ".github/workflows/firmware-and-pages.yml"
)

required_dirs=(
    "src/widgets"
    "src/assets"
    "platformio/src"
    "test"
    "tests"
    "e2e"
)

for path in "${required_files[@]}"; do
    [ -f "${path}" ] || die "Falta: ${path}"
    echo "[OK] ${path}"
done

for path in "${required_dirs[@]}"; do
    [ -d "${path}" ] || die "Falta: ${path}/"
    echo "[OK] ${path}/"
done

# ------------------------------------------------------------
# VERIFY ESPHOME/LVGL LAYER
# ------------------------------------------------------------

echo
echo "=== VERIFY LAYER A | ESPHOME + LVGL + GT911 + ST7701S ==="

grep -q '^lvgl:' src/main.yaml || die "LVGL no está declarado en src/main.yaml."
grep -q 'platform: gt911' src/main.yaml || die "GT911 no está declarado."
grep -q 'platform: st7701s' src/main.yaml || die "ST7701S no está declarado."
grep -q 'width: 480' src/main.yaml || die "width: 480 no encontrado."
grep -q 'height: 480' src/main.yaml || die "height: 480 no encontrado."

grep -q '!secret wifi_ssid' src/main.yaml || die "Falta !secret wifi_ssid."
grep -q '!secret wifi_password' src/main.yaml || die "Falta !secret wifi_password."
grep -q '!secret display_key' src/main.yaml || die "Falta !secret display_key."
grep -q '!secret display_ota' src/main.yaml || die "Falta !secret display_ota."

grep -q 'external_components:' src/main.yaml || die "Falta external_components."
grep -q 'alaltitov/esphome@' src/main.yaml || die "Falta el componente i18n pinneado de alaltitov/esphome."

echo "[OK] ESPHome"
echo "[OK] LVGL"
echo "[OK] GT911"
echo "[OK] ST7701S"
echo "[OK] 480x480"
echo "[OK] i18n external component pinneado"

# ------------------------------------------------------------
# VERIFY PLATFORMIO/3C LAYER
# ------------------------------------------------------------

echo
echo "=== VERIFY LAYER B | PLATFORMIO + 3C ==="

grep -Fq 'moononournation/GFX Library for Arduino@1.5.9' platformio.ini ||     die "Falta GFX Library for Arduino 1.5.9."

# GT911 is intentionally implemented through Wire/I2C in this firmware.
# Do NOT add a second GT911 library unless the firmware architecture changes.
grep -Fq '#include <Arduino_GFX_Library.h>' platformio/src/panel_4848s040/main.cpp ||     die "Falta Arduino_GFX_Library."
grep -Fq '#include <WiFi.h>' platformio/src/panel_4848s040/main.cpp ||     die "Falta WiFi."
grep -Fq '#include <HTTPClient.h>' platformio/src/panel_4848s040/main.cpp ||     die "Falta HTTPClient."
grep -Fq '#include <Wire.h>' platformio/src/panel_4848s040/main.cpp ||     die "Falta Wire/GT911."
grep -Fq 'kTouchAddress = 0x5D' platformio/src/panel_4848s040/main.cpp ||     die "Falta la dirección GT911 0x5D."
grep -Fq 'kScreenWidth = 480' platformio/src/panel_4848s040/main.cpp ||     die "Falta kScreenWidth=480."
grep -Fq 'kScreenHeight = 480' platformio/src/panel_4848s040/main.cpp ||     die "Falta kScreenHeight=480."
grep -Fq 'commandBuffer' platformio/src/panel_4848s040/main.cpp ||     die "Falta commandBuffer."

grep -Fq '/api/device/v1/health' platformio/src/panel_4848s040/main.cpp ||     die "Falta integración API health."
grep -Fq '/api/device/v1/commands' platformio/src/panel_4848s040/main.cpp ||     die "Falta integración API commands."
grep -Fq '2500UL' platformio/src/panel_4848s040/main.cpp ||     die "Falta polling de 2.5 s."

echo "[OK] Arduino-GFX 1.5.9"
echo "[OK] WiFi + HTTPClient"
echo "[OK] Wire + GT911 0x5D"
echo "[OK] 480x480"
echo "[OK] commandBuffer"
echo "[OK] API health/commands"
echo "[OK] polling 2.5 s"

echo
echo "=== RESOLVE PLATFORMIO DEPENDENCIES ==="
pio pkg install --environment panel_4848s040

# ------------------------------------------------------------
# VERIFY API / TEST / CI LAYER
# ------------------------------------------------------------

echo
echo "=== VERIFY API / BACKEND / TESTS / CI ==="

grep -Fq '/api/device/v1/health' backend/device_api.py ||     die "Backend: falta health."
grep -Fq '/api/device/v1/commands' backend/device_api.py ||     die "Backend: falta commands."
grep -Fq 'pending_confirmation' backend/device_api.py ||     die "Backend: falta pending_confirmation."

grep -Fq 'commandBuffer' tests/test_command_editor_integration.py ||     die "Tests: falta commandBuffer."
grep -Fq '2.5' README.md ||     die "README: falta documentar polling 2.5 s."

echo "[OK] backend/device_api.py"
echo "[OK] contract + tests"
echo "[OK] GitHub Actions"

# ------------------------------------------------------------
# WRITE LOCAL ENV
# ------------------------------------------------------------

cat > "${REPO_DIR}/.guition-env" <<EOF
GUITION_REPO_DIR="${REPO_DIR}"
GUITION_REPO_URL="${REPO_URL}"
GUITION_REPO_REF="${REPO_REF}"
GUITION_CONFIG="${REPO_DIR}/src/main.yaml"
GUITION_PLATFORMIO_CONFIG="${REPO_DIR}/platformio.ini"
ESPHOME_VERSION="${ESPHOME_VERSION}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION}"
PANEL_ENVIRONMENT="panel_4848s040"
PANEL_SIZE="480x480"
TOUCH_CONTROLLER="GT911"
DISPLAY_CONTROLLER="ST7701S"
UI_ENGINE="ESPHome/LVGL"
THREE_C_FIRMWARE="PlatformIO/Arduino-GFX"
BUILD_MODE="${BUILD_MODE}"
EOF

echo
echo "[OK] .guition-env"

# ------------------------------------------------------------
# COMPILE BOTH LAYERS THROUGH BLOCK 2
# ------------------------------------------------------------

if [ "${RUN_BUILD}" = "1" ]; then
    echo
    echo "============================================================"
    echo " BLOCK 2 | COMPILE BOTH LAYERS"
    echo "============================================================"
    echo

    BUILD_MODE="${BUILD_MODE}"     BUILD_PLATFORMIO="${BUILD_PLATFORMIO}"     REPO_DIR="${REPO_DIR}"     PROJECT_BASE="${PROJECT_BASE}"     SKIP_GIT_UPDATE=1     "${REPO_DIR}/scripts/02_pull_build_guition.sh"
else
    echo
    echo "[INFO] RUN_BUILD=0: compilación omitida."
fi

echo
echo "============================================================"
echo " BLOCK 1/2 COMPLETE"
echo "============================================================"
echo
echo "ESPHome:"
echo "  LVGL + GT911 + ST7701S + 480x480"
echo
if [ "${BUILD_PLATFORMIO}" = "1" ]; then
    echo "PlatformIO:"
    echo "  3C + Arduino-GFX + GT911(I2C) + Wi-Fi + API"
fi
echo
echo "Local repository:"
echo "  ${REPO_DIR}"
echo
echo "For real credentials:"
echo "  BUILD_MODE=real ./scripts/01_bootstrap_guition.sh"
echo