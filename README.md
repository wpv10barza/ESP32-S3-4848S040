# ESP32-S3-4848S040

Firmware for the Guition ESP32-S3-4848S040 480×480 panel.

## Included

- ESPHome + LVGL UI.
- ST7701S display, 480×480.
- GT911 touch.
- 3C interface with editable command field.
- Virtual keyboard: `ABC/123`, numbers, symbols, space, backspace, enter.
- Command buffer with cursor, insertion, deletion and horizontal viewport.
- Device API: health, command creation, polling and human confirmation/rejection.
- Python/C++ regression tests.
- GitHub Actions CI/CD.
- Optional physical validation with a self-hosted runner.

The ESPHome UI and the PlatformIO 3C firmware are kept as separate build targets so neither UI stack replaces the other.

## Repository layout

```text
src/                         ESPHome + LVGL + ST7701S + GT911
platformio/src/panel_4848s040/  3C firmware + editable keyboard + API client
include/                     command buffer, viewport and keyboard
backend/                     local device API test service
contract/                    API contract
test/ tests/                 native and integration tests
scripts/                     six WSL/Ubuntu execution blocks
.github/workflows/            CI, firmware CD and physical validation
```

## Six blocks

Run from WSL/Ubuntu:

```bash
cd ~/project/ESP32-S3-4848S040

bash scripts/01_clone_guition.sh
bash scripts/02_tools_guition.sh
bash scripts/03_verify_guition.sh
BUILD_MODE=validate bash scripts/04_esphome_guition.sh
bash scripts/05_platformio_guition.sh
PORT=/dev/ttyACM0 bash scripts/06_flash_monitor_guition.sh
```

### Block 1 — clone/update

Only updates the repository. No Python installation and no build.

### Block 2 — tools

Creates `.venv` and ensures exactly:

- ESPHome `2026.8.2`
- PlatformIO `6.2.0`

This block is **safe to re-run**.

### Block 3 — verify

Checks:

- LVGL
- 480×480
- ST7701S
- GT911
- pinned ESPHome component
- command buffer
- virtual keyboard
- 3C API path
- 2.5 s polling

### Block 4 — ESPHome

Validates and compiles `src/main.yaml`.

Use:

```bash
BUILD_MODE=validate bash scripts/04_esphome_guition.sh
```

for CI-style dummy secrets, or:

```bash
BUILD_MODE=real bash scripts/04_esphome_guition.sh
```

for local real secrets.

### Block 5 — PlatformIO

Runs native regression tests and builds:

```text
panel_4848s040
```

### Block 6 — physical device

Uploads the firmware and opens the serial monitor.

```bash
PORT=/dev/ttyACM0 bash scripts/06_flash_monitor_guition.sh
```

## Resume after the interruption you reported

Your installation stopped after:

```text
Uninstalling platformio-6.1.19:
Successfully uninstalled platformio-6.1.19
```

That means the correct resume point is **Block 2**. Do not repeat Block 1.

```bash
cd ~/project/ESP32-S3-4848S040

bash scripts/02_tools_guition.sh
bash scripts/03_verify_guition.sh
BUILD_MODE=validate bash scripts/04_esphome_guition.sh
bash scripts/05_platformio_guition.sh
PORT=/dev/ttyACM0 bash scripts/06_flash_monitor_guition.sh
```

Block 2 first checks whether the requested versions are already installed. If PlatformIO 6.2.0 was not completed, it installs it; if it is already present, it skips the reinstall.

## Upstream Guition sync

The repository includes the complete Guition source tree from `alaltitov/Guition-ESP32-S3-4848S040` branch `2026.8.2`, synced from commit `1c5143b1204e5acb337f3487cfba69ad4a72abe3`. The sync contains all 152 upstream file blobs; this repository also keeps the 3C/backend/CI additions on top.

The upstream ESPHome configuration uses one external component, `i18n`, from `alaltitov/esphome@dev`. This repository pins it to the verified commit `1b487af0ef26ff8e7908d34e415d99cc13fc1f98` for reproducible builds.

## Physical flash from WSL2

Do not use `/dev/ttyS0` for the ESP32-S3 USB upload path. Block 6 rejects `/dev/ttyS*` and searches, in order, for `/dev/serial/by-id/*`, `/dev/ttyACM*`, and `/dev/ttyUSB*`.

From WSL:

```bash
cd ~/project/ESP32-S3-4848S040
bash scripts/02_tools_guition.sh
bash scripts/03_verify_guition.sh
bash scripts/05_platformio_guition.sh
PORT=/dev/ttyACM0 bash scripts/06_flash_monitor_guition.sh
```

For a stable device path, prefer `PORT=/dev/serial/by-id/...`. If no serial device appears in WSL2, attach the USB device to WSL first and then verify it with `lsusb` and `pio device list`.

## API flow

```text
POST /api/device/v1/commands
        |
        v
pending_confirmation
        |
        | human confirmation in backend
        +------> applied
        |
        +------> rejected

device polls every 2.5 s
transport/protocol failure -> ERROR
```

The device does not call the confirm/reject endpoints.

## Physical validation

Cloud CI proves source, tests and firmware compilation. It does not prove that a physical ESP32-S3, ST7701S or GT911 is electrically connected and operating.

Use:

```text
.github/workflows/physical-validation.yml
```

with a self-hosted runner connected to the board.

## Important ESPHome warning

The current panel configuration uses GPIO19 for GT911 I²C and GPIO20 as part of the RGB display bus. ESPHome can therefore warn about overlap with the USB-Serial-JTAG interface. Treat those warnings as a hardware/port-usage consideration during physical validation; do not treat them as proof that the panel is working.
