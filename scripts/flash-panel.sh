#!/usr/bin/env bash
set -Eeuo pipefail

# Compatibility wrapper: physical flash/monitor is now BLOCK 6.
cd "$(dirname "$0")/.."
exec "$(pwd)/scripts/06_flash_monitor_guition.sh" "$@"
