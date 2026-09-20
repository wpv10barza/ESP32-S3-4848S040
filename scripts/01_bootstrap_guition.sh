#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# GUITION ESP32-S3-4848S040
# BLOCK 1 | CLONE / VENV / ESPHOME + PLATFORMIO / VERIFY
# ============================================================

PROJECT_BASE="${PROJECT_BASE:-${HOME}/project}"
REPO_DIR="${REPO_DIR:-${PROJECT_BASE}/COPIA2}"

# This is YOUR merged repository. Never bootstrap from the upstream
# Guition repository here, otherwise the 3C/API/CI layer is lost.
REPO_URL="${REPO_URL:-https://github.com/wpv10barza/ESP32-S3-4848S040.git}"
REPO_REF="${REPO_REF:-main}"

ESPHOME_VERSION="${ESPHOME_VERSION:-2026.8.2}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION:-6.2.0}"
VENV_DIR="${REPO_DIR}/.venv"

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

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "$1 no está instalado."
}

echo "============================================================"
echo " GUITION ESP32-S3-4848S040"
echo " BLOCK 1 | CLONE / VENV / ESPHOME + PLATFORMIO / VERIFY"
echo "============================================================"

require_cmd git
require_cmd python3
python3 -m venv --help >/dev/null 2>&1 || die "python3-venv no está disponible."

mkdir -p "${PROJECT_BASE}"

echo
echo "Project base : ${PROJECT_BASE}"
echo "Repository   : ${REPO_DIR}"
echo "Repository   : ${REPO_URL}"
echo "Ref          : ${REPO_REF}"
echo "ESPHome      : ${ESPHOME_VERSION}"
echo "PlatformIO   : ${PLATFORMIO_VERSION}"

# ------------------------------------------------------------
# CLONE / UPDATE
# ------------------------------------------------------------

if [ ! -d "${REPO_DIR}/.git" ]; then
    if [ -e "${REPO_DIR}" ]; then
        die "Existe ${REPO_DIR}, pero no es un repositorio Git."
    fi

    echo
    echo "=== CLONANDO TU REPOSITORIO ==="
    git clone --branch "${REPO_REF}" --single-branch "${REPO_URL}" "${REPO_DIR}"
else
    cd "${REPO_DIR}"

    CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null || true)"
    [ "${CURRENT_REMOTE}" = "${REPO_URL}" ] || {
        echo "[ERROR] origin apunta a:"
        echo "  ${CURRENT_REMOTE:-<sin origin>}"
        echo
        echo "Debe apuntar a:"
        echo "  ${REPO_URL}"
        exit 2
    }

    echo
    echo "=== ACTUALIZANDO REPOSITORIO ==="
    git fetch --tags --prune origin
    git checkout "${REPO_REF}" >/dev/null 2>&1 || die "No se pudo seleccionar ${REPO_REF}."

    if git symbolic-ref -q HEAD >/dev/null 2>&1; then
        git pull --ff-only origin "${REPO_REF}" ||             die "La rama ${REPO_REF} tiene cambios locales/no fast-forward."
    fi
fi

cd "${REPO_DIR}"

echo
echo "=== GIT ==="
echo "Remote:"
git remote -v
echo
echo "Ref:"
git describe --always --tags --dirty
echo
echo "Commit:"
git log -1 --oneline --decorate

# ------------------------------------------------------------
# VENV
# ------------------------------------------------------------

echo
echo "=== PYTHON VENV ==="

if [ ! -d "${VENV_DIR}" ]; then
    python3 -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python -m pip install --disable-pip-version-check --upgrade pip setuptools wheel

echo
echo "=== INSTALL ESPHOME ==="
python -m pip install --disable-pip-version-check "esphome==${ESPHOME_VERSION}"

echo
echo "Python:"
python --version
echo
echo "ESPHome:"
esphome version

echo
echo "=== INSTALL PLATFORMIO ==="
python -m pip install --disable-pip-version-check "platformio==${PLATFORMIO_VERSION}"

echo
echo "PlatformIO:"
pio --version

# ------------------------------------------------------------
# VERIFY REPOSITORY STRUCTURE
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
    [ -f "${path}" ] || die "Falta el archivo: ${path}"
    echo "[OK] ${path}"
done

for path in "${required_dirs[@]}"; do
    [ -d "${path}" ] || die "Falta el directorio: ${path}"
    echo "[OK] ${path}/"
done

# ------------------------------------------------------------
# VERIFY ESPHOME UI LAYER
#
# IMPORTANT:
# src/main.yaml uses !secret. Block 1 does NOT compile it.
# Block 2 is responsible for the secret-aware config/compile
# using either real credentials or an isolated temporary copy.
# ------------------------------------------------------------

echo
echo "=== VERIFY ESPHOME UI LAYER ==="

grep -q '^lvgl:' src/main.yaml || die "src/main.yaml no declara LVGL."
grep -q 'platform: gt911' src/main.yaml || die "src/main.yaml no declara GT911."
grep -q 'platform: st7701s' src/main.yaml || die "src/main.yaml no declara ST7701S."
grep -q 'width: 480' src/main.yaml || die "No se encontró width: 480."
grep -q 'height: 480' src/main.yaml || die "No se encontró height: 480."
grep -q '!secret wifi_ssid' src/main.yaml || die "Falta !secret wifi_ssid."
grep -q '!secret wifi_password' src/main.yaml || die "Falta !secret wifi_password."
grep -q '!secret display_key' src/main.yaml || die "Falta !secret display_key."
grep -q '!secret display_ota' src/main.yaml || die "Falta !secret display_ota."

echo "[OK] LVGL"
echo "[OK] GT911"
echo "[OK] ST7701S"
echo "[OK] 480x480"
echo "[OK] ESPHome !secret references"
echo "[INFO] No se ejecuta 'esphome config' en BLOCK 1 porque faltan credenciales por diseño."
echo "[INFO] Use BLOCK 2 para BUILD_MODE=real o BUILD_MODE=validate."

# ------------------------------------------------------------
# VERIFY PLATFORMIO 3C LAYER
# ------------------------------------------------------------

echo
echo "=== VERIFY PLATFORMIO 3C LAYER ==="

grep -Fq 'moononournation/GFX Library for Arduino@1.5.9' platformio.ini ||     die "platformio.ini no declara GFX Library for Arduino 1.5.9."
grep -Fq '#include <Arduino_GFX_Library.h>' platformio/src/panel_4848s040/main.cpp ||     die "Falta Arduino_GFX_Library."
grep -Fq '#include <WiFi.h>' platformio/src/panel_4848s040/main.cpp ||     die "Falta WiFi.h."
grep -Fq '#include <HTTPClient.h>' platformio/src/panel_4848s040/main.cpp ||     die "Falta HTTPClient.h."
grep -Fq '#include <Wire.h>' platformio/src/panel_4848s040/main.cpp ||     die "Falta Wire.h/GT911."
grep -Fq 'kTouchAddress = 0x5D' platformio/src/panel_4848s040/main.cpp ||     die "Falta GT911 I2C 0x5D."
grep -Fq 'kScreenWidth = 480' platformio/src/panel_4848s040/main.cpp ||     die "Falta ancho 480."
grep -Fq 'kScreenHeight = 480' platformio/src/panel_4848s040/main.cpp ||     die "Falta alto 480."
grep -Fq 'commandBuffer' platformio/src/panel_4848s040/main.cpp ||     die "Falta commandBuffer."

echo "[OK] Arduino-GFX 1.5.9"
echo "[OK] WiFi"
echo "[OK] HTTPClient"
echo "[OK] Wire / GT911"
echo "[OK] Panel 480x480"
echo "[OK] commandBuffer / editor"

echo
echo "=== PLATFORMIO DEPENDENCY RESOLUTION ==="
pio pkg install -e panel_4848s040

# ------------------------------------------------------------
# VERIFY API / BACKEND / TESTS / CI
# ------------------------------------------------------------

echo
echo "=== VERIFY API / BACKEND / TESTS / CI ==="

grep -Fq '/api/device/v1/health' backend/device_api.py || die "Falta endpoint health."
grep -Fq '/api/device/v1/commands' backend/device_api.py || die "Falta endpoint commands."
grep -Fq 'pending_confirmation' backend/device_api.py || die "Falta pending_confirmation."
grep -Fq 'commandBuffer' tests/test_command_editor_integration.py ||     die "Falta integración de commandBuffer en tests."
grep -Fq '2.5' README.md || die "README.md no documenta polling de 2.5 s."

echo "[OK] API v1"
echo "[OK] pending_confirmation"
echo "[OK] editor/commandBuffer tests"
echo "[OK] polling 2.5 s"
echo "[OK] GitHub Actions"

# ------------------------------------------------------------
# ENVIRONMENT FILE
# ------------------------------------------------------------

cat > "${REPO_DIR}/.guition-env" <<EOF
GUITION_REPO_DIR="${REPO_DIR}"
GUITION_CONFIG="${REPO_DIR}/src/main.yaml"
GUITION_PLATFORMIO_CONFIG="${REPO_DIR}/platformio.ini"
GUITION_REPO_URL="${REPO_URL}"
GUITION_REPO_REF="${REPO_REF}"
ESPHOME_VERSION="${ESPHOME_VERSION}"
PLATFORMIO_VERSION="${PLATFORMIO_VERSION}"
PANEL_ENVIRONMENT="panel_4848s040"
PANEL_SIZE="480x480"
TOUCH_CONTROLLER="GT911"
DISPLAY_CONTROLLER="ST7701S"
UI_ENGINE="ESPHome/LVGL"
THREE_C_FIRMWARE="PlatformIO/Arduino-GFX"
EOF

echo
echo "[OK] .guition-env creado."

echo
echo "============================================================"
echo " BLOCK 1 SUCCESS"
echo "============================================================"
echo
echo "Repositorio:"
echo "  ${REPO_DIR}"
echo
echo "Venv:"
echo "  ${VENV_DIR}"
echo
echo "ESPHome:"
echo "  ${ESPHOME_VERSION}"
echo
echo "PlatformIO:"
echo "  ${PLATFORMIO_VERSION}"
echo
echo "UI:"
echo "  ESPHome + LVGL + ST7701S + GT911 + 480x480"
echo
echo "3C:"
echo "  PlatformIO + Arduino-GFX + WiFi + HTTPClient + Wire"
echo
echo "Next:"
echo "  cd ${REPO_DIR}"
echo "  source .venv/bin/activate"
echo "  ./scripts/02_pull_build_guition.sh --mode validate"
echo "  # o, para compilación real:"
echo "  ./scripts/02_pull_build_guition.sh --mode real"
echo
