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

# ESPHome 2026.8.2 requires Python >=3.12,<3.15.
ESPHOME_VERSION="${ESPHOME_VERSION:-2026.8.2}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION:-6.2.0}"

VENV_DIR="${REPO_DIR}/.venv"
LOG_DIR="${REPO_DIR}/.ci"
BOOTSTRAP_LOG="${LOG_DIR}/bootstrap.log"

BUILD_MODE="${BUILD_MODE:-validate}"
BUILD_PLATFORMIO="${BUILD_PLATFORMIO:-1}"
RUN_BUILD="${RUN_BUILD:-1}"

mkdir -p "${LOG_DIR}"
touch "${BOOTSTRAP_LOG}"

# Keep a persistent log so a VS Code/WSL terminal exit code 1 does not
# erase the useful error message.
exec > >(tee -a "${BOOTSTRAP_LOG}") 2>&1

die() {
    echo "[ERROR] $*" >&2
    return 1
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
    echo "Bootstrap : ${BOOTSTRAP_LOG}"
    echo "============================================================"
    echo
    echo "Python candidates:"
    command -v python3.13 || true
    command -v python3.12 || true
    command -v python3 || true
    echo
    echo "Python version:"
    python3 --version 2>&1 || true
    echo
    echo "Venv path:"
    echo "  ${VENV_DIR}"
    echo
    echo "Full log:"
    echo "  ${BOOTSTRAP_LOG}"
    exit "${rc}"
}
trap on_error ERR

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        die "$1 no está instalado."
        exit 1
    }
}

select_python() {
    local candidate
    local major
    local minor

    for candidate in python3.13 python3.12 python3; do
        if ! command -v "${candidate}" >/dev/null 2>&1; then
            continue
        fi

        read -r major minor _ < <("${candidate}" -c 'import sys; print(sys.version_info.major, sys.version_info.minor, sys.version_info.micro)')
        if [[ "${major}" -eq 3 && "${minor}" -ge 12 && "${minor}" -lt 15 ]]; then
            PYTHON_BIN="$(command -v "${candidate}")"
            PYTHON_MAJOR="${major}"
            PYTHON_MINOR="${minor}"
            return 0
        fi
    done

    echo "[ERROR] ESPHome ${ESPHOME_VERSION} requiere Python >=3.12,<3.15." >&2
    echo "[ERROR] Python disponible en WSL: $(python3 --version 2>&1 || true)" >&2
    echo "[ERROR] Instala Python 3.12+ y python3-venv en Ubuntu/WSL." >&2
    return 1
}

case "${BUILD_MODE}" in
    validate|real) ;;
    *) die "BUILD_MODE debe ser 'validate' o 'real'." ; exit 64 ;;
esac

case "${BUILD_PLATFORMIO}" in
    0|1) ;;
    *) die "BUILD_PLATFORMIO debe ser 0 o 1." ; exit 64 ;;
esac

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
echo "Log        : ${BOOTSTRAP_LOG}"
echo

require_cmd git

# Select a Python interpreter compatible with the pinned ESPHome.
select_python

echo "[OK] Python seleccionado: ${PYTHON_BIN}"
"${PYTHON_BIN}" --version

# Verify venv support before touching the project.
"${PYTHON_BIN}" -m venv --help >/dev/null 2>&1 || {
    echo "[ERROR] El intérprete ${PYTHON_BIN} no tiene soporte venv."
    echo "[ERROR] En Ubuntu suele requerir el paquete python3-venv correspondiente."
    exit 1
}

mkdir -p "${PROJECT_BASE}"

# ------------------------------------------------------------
# CLONE / UPDATE THE MERGED REPOSITORY
# ------------------------------------------------------------

if [ ! -d "${REPO_DIR}/.git" ]; then
    [ ! -e "${REPO_DIR}" ] || {
        echo "[ERROR] Existe ${REPO_DIR}, pero no es un repositorio Git."
        exit 1
    }

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
        echo "[ERROR] Hay cambios locales. Haz commit/stash antes de actualizar."
        exit 2
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
git branch --show-current
git log -1 --oneline --decorate

# ------------------------------------------------------------
# PYTHON VENV
# ------------------------------------------------------------

echo
echo "=== PYTHON VENV ==="

if [ ! -d "${VENV_DIR}" ]; then
    echo "[INFO] Creando venv con ${PYTHON_BIN}"
    "${PYTHON_BIN}" -m venv "${VENV_DIR}"
fi

[ -f "${VENV_DIR}/bin/activate" ] || {
    echo "[ERROR] No se creó correctamente ${VENV_DIR}/bin/activate."
    exit 1
}

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "[OK] Venv activo:"
echo "  $(python --version)"
echo "  $(python -m pip --version)"

# Use the venv's pip. Do not upgrade the system Python.
python -m pip install     --disable-pip-version-check     --upgrade     pip setuptools wheel

echo "[OK] pip/setuptools/wheel"

# ------------------------------------------------------------
# INSTALL TOOLCHAIN
# ------------------------------------------------------------

echo
echo "=== INSTALL ESPHOME ${ESPHOME_VERSION} ==="
python -m pip install     --disable-pip-version-check     --upgrade     "esphome==${ESPHOME_VERSION}"

echo "[OK] ESPHome $(esphome version)"

echo
echo "=== INSTALL PLATFORMIO ${PLATFORMIO_VERSION} ==="
python -m pip install     --disable-pip-version-check     --upgrade     "platformio==${PLATFORMIO_VERSION}"

echo "[OK] PlatformIO $(pio --version)"

# ------------------------------------------------------------
# VERIFY MERGED REPOSITORY
# ------------------------------------------------------------

echo
echo "=== VERIFY MERGED REPOSITORY ==="

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
    [ -f "${path}" ] || {
        echo "[ERROR] Falta: ${path}"
        exit 1
    }
    echo "[OK] ${path}"
done

for path in "${required_dirs[@]}"; do
    [ -d "${path}" ] || {
        echo "[ERROR] Falta: ${path}/"
        exit 1
    }
    echo "[OK] ${path}/"
done

# ------------------------------------------------------------
# VERIFY ESPHOME/LVGL
# ------------------------------------------------------------

echo
echo "=== VERIFY LAYER A | ESPHOME + LVGL + GT911 + ST7701S ==="

grep -q '^lvgl:' src/main.yaml
grep -q 'platform: gt911' src/main.yaml
grep -q 'platform: st7701s' src/main.yaml
grep -q 'width: 480' src/main.yaml
grep -q 'height: 480' src/main.yaml
grep -q '!secret wifi_ssid' src/main.yaml
grep -q '!secret wifi_password' src/main.yaml
grep -q '!secret display_key' src/main.yaml
grep -q '!secret display_ota' src/main.yaml
grep -q 'external_components:' src/main.yaml
grep -q 'alaltitov/esphome@' src/main.yaml

echo "[OK] ESPHome + LVGL + GT911 + ST7701S + 480x480"
echo "[OK] i18n external component pinneado"

# ------------------------------------------------------------
# VERIFY PLATFORMIO/3C
# ------------------------------------------------------------

echo
echo "=== VERIFY LAYER B | PLATFORMIO + 3C ==="

grep -Fq 'moononournation/GFX Library for Arduino@1.5.9' platformio.ini
grep -Fq '#include <Arduino_GFX_Library.h>' platformio/src/panel_4848s040/main.cpp
grep -Fq '#include <WiFi.h>' platformio/src/panel_4848s040/main.cpp
grep -Fq '#include <HTTPClient.h>' platformio/src/panel_4848s040/main.cpp
grep -Fq '#include <Wire.h>' platformio/src/panel_4848s040/main.cpp
grep -Fq 'kTouchAddress = 0x5D' platformio/src/panel_4848s040/main.cpp
grep -Fq 'kScreenWidth = 480' platformio/src/panel_4848s040/main.cpp
grep -Fq 'kScreenHeight = 480' platformio/src/panel_4848s040/main.cpp
grep -Fq 'commandBuffer' platformio/src/panel_4848s040/main.cpp
grep -Fq '/api/device/v1/health' platformio/src/panel_4848s040/main.cpp
grep -Fq '/api/device/v1/commands' platformio/src/panel_4848s040/main.cpp
grep -Fq '2500UL' platformio/src/panel_4848s040/main.cpp

# The 3C PlatformIO firmware uses Arduino-GFX directly.
# LVGL remains in ESPHome, avoiding a second lv_conf.h/LVGL build.
if grep -Fq 'lvgl/lvgl' platformio.ini; then
    echo "[ERROR] platformio.ini no debe enlazar lvgl/lvgl en la capa 3C."
    exit 1
fi

echo "[OK] Arduino-GFX 1.5.9"
echo "[OK] Wire/GT911 0x5D"
echo "[OK] WiFi + HTTPClient"
echo "[OK] commandBuffer + API + polling 2.5 s"
echo "[OK] No second LVGL dependency in PlatformIO"

# ------------------------------------------------------------
# API / TEST / CI
# ------------------------------------------------------------

echo
echo "=== VERIFY API / TESTS / CI ==="

grep -Fq '/api/device/v1/health' backend/device_api.py
grep -Fq '/api/device/v1/commands' backend/device_api.py
grep -Fq 'pending_confirmation' backend/device_api.py
grep -Fq 'commandBuffer' tests/test_command_editor_integration.py
grep -Fq '2.5' README.md

echo "[OK] backend/API"
echo "[OK] tests"
echo "[OK] polling 2.5 s"
echo "[OK] GitHub Actions"

# ------------------------------------------------------------
# ENVIRONMENT FILE
# ------------------------------------------------------------

cat > "${REPO_DIR}/.guition-env" <<EOF
GUITION_REPO_DIR="${REPO_DIR}"
GUITION_REPO_URL="${REPO_URL}"
GUITION_REPO_REF="${REPO_REF}"
GUITION_CONFIG="${REPO_DIR}/src/main.yaml"
GUITION_PLATFORMIO_CONFIG="${REPO_DIR}/platformio.ini"
ESPHOME_VERSION="${ESPHOME_VERSION}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION}"
PYTHON_BIN="${PYTHON_BIN}"
PYTHON_VERSION="$(python --version)"
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
# COMPILE BOTH LAYERS
# ------------------------------------------------------------

if [ "${RUN_BUILD}" = "1" ]; then
    echo
    echo "============================================================"
    echo " BLOCK 2 | COMPILE BOTH LAYERS"
    echo "============================================================"

    BUILD_MODE="${BUILD_MODE}"     BUILD_PLATFORMIO="${BUILD_PLATFORMIO}"     REPO_DIR="${REPO_DIR}"     PROJECT_BASE="${PROJECT_BASE}"     SKIP_GIT_UPDATE=1     "${REPO_DIR}/scripts/02_pull_build_guition.sh"
else
    echo
    echo "[INFO] RUN_BUILD=0: compilación omitida."
fi

echo
echo "============================================================"
echo " BLOCK 1 COMPLETE"
echo "============================================================"
echo
echo "Python:"
echo "  $(python --version)"
echo
echo "ESPHome:"
echo "  $(esphome version)"
echo
echo "PlatformIO:"
echo "  $(pio --version)"
echo
echo "Layer A: ESPHome + LVGL + GT911 + ST7701S + 480x480"
echo "Layer B: PlatformIO + 3C + Arduino-GFX + GT911 + API"
echo
echo "Log:"
echo "  ${BOOTSTRAP_LOG}"
echo
