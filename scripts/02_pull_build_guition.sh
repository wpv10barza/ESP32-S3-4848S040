#!/usr/bin/env bash
set -Eeuo pipefail

# Compatibility wrapper: old BLOCK 2 now maps to validation/build Blocks 3–5.
PROJECT_BASE="${PROJECT_BASE:-${HOME}/project}"
REPO_DIR="${REPO_DIR:-${PROJECT_BASE}/ESP32-S3-4848S040}"
BUILD_MODE="${BUILD_MODE:-validate}"

PROJECT_BASE="${PROJECT_BASE}" REPO_DIR="${REPO_DIR}" bash "${REPO_DIR}/scripts/03_verify_guition.sh"
PROJECT_BASE="${PROJECT_BASE}" REPO_DIR="${REPO_DIR}" BUILD_MODE="${BUILD_MODE}" bash "${REPO_DIR}/scripts/04_esphome_guition.sh"
PROJECT_BASE="${PROJECT_BASE}" REPO_DIR="${REPO_DIR}" bash "${REPO_DIR}/scripts/05_platformio_guition.sh"
