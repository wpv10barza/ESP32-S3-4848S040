#!/usr/bin/env bash
set -Eeuo pipefail

# Compatibility wrapper: the old BLOCK 1 command now runs only Blocks 1 and 2.
PROJECT_BASE="${PROJECT_BASE:-${HOME}/project}"
REPO_DIR="${REPO_DIR:-${PROJECT_BASE}/ESP32-S3-4848S040}"

PROJECT_BASE="${PROJECT_BASE}" REPO_DIR="${REPO_DIR}" bash "${REPO_DIR}/scripts/01_clone_guition.sh"
PROJECT_BASE="${PROJECT_BASE}" REPO_DIR="${REPO_DIR}" bash "${REPO_DIR}/scripts/02_tools_guition.sh"
