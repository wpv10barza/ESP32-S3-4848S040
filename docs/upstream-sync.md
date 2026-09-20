# Guition upstream sync

This repository carries the Guition ESP32-S3-4848S040 source tree from:

- Upstream: https://github.com/alaltitov/Guition-ESP32-S3-4848S040
- Upstream branch: `2026.8.2`
- Upstream commit at sync: `1c5143b1204e5acb337f3487cfba69ad4a72abe3`
- Source tree files at sync: 152 blobs

The private project additions (PlatformIO 3C firmware, backend/API contract,
native/integration tests, and GitHub Actions) remain in this repository.

## ESPHome external component

The upstream `src/main.yaml` references the i18n component from
`alaltitov/esphome@dev`. This repository pins that dependency to the verified
commit:

`1b487af0ef26ff8e7908d34e415d99cc13fc1f98`

This avoids a floating `dev` dependency while keeping the required i18n component.

## Physical upload policy

The physical-flash block deliberately does not use `/dev/ttyS*`. It checks for
a real character device and prefers stable udev paths, then `/dev/ttyACM*` and
`/dev/ttyUSB*`.

On WSL2, the USB device must first be attached to WSL. Microsoft documents the
USB/IP flow with `usbipd list`, `usbipd bind --busid ...`, and
`usbipd attach --wsl --busid ...`; once attached, verify the device from WSL
with `lsusb` and the serial node under `/dev`.
