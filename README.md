<div style="
    display: flex;
    justify-content: center;
    border: 3px solid #3774ee; 
    border-radius: 18px; 
    padding: 15px;
    color: white;
">
    My new <a href="https://alaltitov.github.io/DarkForgeUI-firmware" style="color: #3774ee; font-weight: bold; text-decoration: underline; margin: 0 5px;"> project </a> for ESP32-S3/P4 smart home devices. No Code. No Compile.
</div>

##

# LVGL ESPhome Guition ESP32-S3-4848S040 custom firmware

<p align="center">
 <img width="200px" src="/doc/images/loading.png">
 <img width="200px" src="/doc/images/home.png">
 <img width="200px" src="/doc/images/forecasts.png">
 <img width="200px" src="/doc/images/info.png">
 <img width="200px" src="/doc/images/settings.png">
 <img width="200px" src="/doc/images/light0.png">
 <img width="200px" src="/doc/images/light1.png">
 <img width="200px" src="/doc/images/climate0.png">
 <img width="200px" src="/doc/images/climate1.png">
 <img width="200px" src="/doc/images/climate2.png">
 <img width="200px" src="/doc/images/climate3.png">
 <img width="200px" src="/doc/images/media_player.png">
 <img width="200px" src="/doc/images/vacuum.png">
</p>

<p align="center">
    <img alt="Static Badge" src="https://img.shields.io/badge/made%20by-alaltitov-blue">
    <img alt="Static Badge" src="https://img.shields.io/badge/version-v1.0%20Dev-green">
    <img alt="Static Badge" src="https://img.shields.io/badge/esphome test version-2025.9.3-red">
    <img alt="Static Badge" src="https://img.shields.io/badge/license-MIT-orange">
</p>

## Support the Project

<img src="/doc/images/donate.png" alt="QR Code" width="150" align="left" hspace="10"/>

<div style="padding-top: 40px;">
  <b>Support me on</b>
  <div style="height: 30px;"></div>
  <a href="https://boosty.to/altitov/donate">
    <img src="/doc/images/boosty.png" alt="Boosty" width="160"/>
  </a>
</div>

<br clear="all"/>

## ⚠️ Important Notice
- Support for new versions will be provided only for the release version (while the dev branch is in effect) 
- Beta and alpha versions will not be supported taking into account new versions of ESPHome.

## ✨ Features

- Status indicators for Wi-Fi, Home Assistant API, thermostat, air conditioner, touchscreen lock, alarm panel
- Weather icons with current conditions and temperature
- Weather Forecasts daily and hourly
- Date and time
- Sensor readings from Home Assistant
- Climate control (auto)
- Lights control (auto)
- Media player
- Other controls (for example, vacuum, alarm panel, shutter, fan, switchs...) coming soon
- Settings:
  * Backlight adjustment
  * Screen timeout settings
  * Language selection:
    - ru (from [alaltitov](https://github.com/alaltitov))
    - en (from [alaltitov](https://github.com/alaltitov))
    - pl (from [reaper7](https://github.com/reaper7))
    - fr (from [lboue](https://github.com/lboue))
    - es (from Antonio)
    - nl (from [zjean](https://github.com/zjean))
    - si (from [Protoncek](https://github.com/Protoncek))
    - it (from [echopage1964](https://github.com/echopage1964))
    - de (from [MATZE-MAN](https://github.com/MATZE-MAN))
    - dk (from [petanque](https://github.com/petanque))
    - br (from [pehdepano](https://github.com/pehdepano))
    - he


## 📦 Installation
> 📹 **Video [instruction](https://youtu.be/HYN_2hvcbes?si=JfYQH4vCuFlr8Q9r)**

<img width="400px" src="/doc/images/ha_options.png">

- You must enable the "Allow the device to perform Home Assistant actions." option in the ESPHome integration to Home Assistant to control devices.
- Install custom component for forecasts and covers for media player from [here](https://github.com/alaltitov/homeassistant-display-tools).
- Copy repository to vscode or to esphome folder of your Home Assistant. Change in substitutions.yaml and config.yaml (light folder) your entities in all widgets (only in substitution, in code everything will be substituted automatically).

## 📖 Documentation
- [Firmware](https://alaltitov.github.io/Guition-ESP32-S3-4848S040-DOCS)  (Need update, coming soon...)
- [ESPHome LVGL 8.4](https://esphome.io/components/lvgl/)

## 🤝 Thanks for your help
- Thanks to [ZHNovell](https://github.com/ZHNovell) for financial support of the project, as well as for help with testing and ideas.
- Thanks, [сlydebarrow](https://github.com/clydebarrow), [jesserockz](https://github.com/jesserockz), [ssieb](https://github.com/ssieb) for helping me with the project!

---

# Capas de validación añadidas en este fork

Este repositorio conserva la base ESPHome/LVGL del proyecto original y añade una capa separada de validación PlatformIO/API.

## Estado técnico

| Requisito | Estado |
|---|---|
| GitHub Actions | ✅ `.github/workflows/ci.yml` |
| Workflow PlatformIO/firmware | ✅ `pio test -e native` + `pio run -e esp32s3` |
| Tests `test/` | ✅ command flow, command buffer, hit testing |
| `platformio.ini` | ✅ native + ESP32-S3 |
| `/api/device/v1/...` | ✅ health, commands, status, confirm/reject |
| `pending_confirmation` + polling | ✅ flujo implementado; polling del firmware cada 2.5 s |
| Bloqueo de comandos vacíos | ✅ firmware core + API E2E |
| Validación física ESP32 | ⚠️ requiere runner self-hosted conectado al hardware |

## API y confirmación humana

El dispositivo publica una orden y recibe `pending_confirmation`. El dispositivo solamente consulta el estado; no ejecuta la confirmación por sí mismo.

La transición a `applied` o `rejected` se realiza mediante la ruta de confirmación del backend, representando la aprobación humana. El servicio de prueba incluido en el repositorio no escribe en Google Sheets.

Consulta `docs/api-e2e.md` y `docs/validation-matrix.md`.

## PlatformIO

El proyecto PlatformIO está separado del firmware ESPHome original:

- `platformio.ini`
- `platformio/src/`
- `test/`

Esto evita convertir `src/main.yaml` en una aplicación PlatformIO y mantiene intacta la interfaz LVGL/ST7701/GT911 del proyecto base.

## Validación física

Un runner GitHub alojado en la nube no puede demostrar que una placa ESP32-S3 física haya arrancado, que ST7701/GT911 respondan, ni que USB-C, audio, GPIO, PSRAM y alimentación estén estables.

Para eso se añadió el workflow manual `.github/workflows/physical-validation.yml`, pensado para un runner **self-hosted** conectado físicamente a la placa. La evidencia se conserva como artefacto de logs serie.

**No se marca como validación física hasta ejecutar ese workflow con hardware conectado.**

---

## Integración ESP32 firmware backend 3C

El repositorio conserva la interfaz original **ESPHome/LVGL** para el panel 480×480 y agrega un firmware PlatformIO independiente para el flujo 3C.

### Panel 480×480 + GT911
- Firmware activo: `platformio/src/panel_4848s040/main.cpp`
- Driver de pantalla: ST7701 mediante Arduino-GFX.
- Táctil: GT911 por I²C.
- Editor real de comandos: `commandBuffer`, cursor, inserción, backspace, delete y desplazamiento horizontal.
- Teclado virtual: letras, números, símbolos, espacio, backspace, enter y cambio `ABC/123`.
- Zonas táctiles principales: `PROBAR WSL` y `ENVIAR 3C`.

### API 3C
Se incorporan el backend de pruebas y su contrato:
- `backend/device_api.py`
- `contract/device-command-v1.json`
- `GET /api/device/v1/health`
- `POST /api/device/v1/commands`
- `GET /api/device/v1/commands/{command_id}`
- confirmación/rechazo humano antes del estado final.
- polling del firmware cada 2.5 s.
- bloqueo de comandos vacíos.

### CI y pruebas
Se incorporan los workflows y pruebas del backend, además de las pruebas PlatformIO existentes. Los tests C++ del backend se organizan en suites independientes para evitar múltiples `main()` en un mismo ejecutable.

### LVGL
La base ESPHome/LVGL original no se reemplaza. El entorno `panel_4848s040` incluye LVGL 8.4 como dependencia, pero la UI 3C importada del ZIP actualmente dibuja con Arduino-GFX y lee GT911 directamente. Esto mantiene separadas las dos capas de interfaz en lugar de mezclar dos motores de renderizado en el mismo ciclo de dibujo.

### Compilación y carga física

```bash
pio run -e panel_4848s040
./scripts/flash-panel.sh
```

La carga física requiere la placa conectada al entorno WSL/Ubuntu y un `include/local_config.h` local con las credenciales y URL del backend.

## 🔐 Secret-aware Block 2

The upstream ESPHome base is mirrored in this repository, including `src/main.yaml`. That file intentionally uses ESPHome `!secret` references for Wi-Fi, API encryption and OTA credentials; real credentials are never committed.

Block 2 now has two explicit modes:

```bash
# Real local device build: requires src/secrets.yaml
BUILD_MODE=real ./scripts/02_pull_build_guition.sh

# CI / structure validation: isolated temporary ESPHome workspace
BUILD_MODE=validate ./scripts/02_pull_build_guition.sh
```

In `real` mode, Block 2 requires non-empty `wifi_ssid`, `wifi_password`, `display_key` and `display_ota` in the local ignored `src/secrets.yaml`.

In `validate` mode, Block 2 copies `src/` to a temporary directory and creates a temporary `secrets.yaml` there. The real `src/secrets.yaml`, when present, is untouched. The temporary build is never treated as a production flashing artifact.

GitHub Actions calls the same validation mode with `BUILD_PLATFORMIO=0` so the `!secret` graph is actually parsed and compiled without requiring production credentials. The separate PlatformIO firmware remains validated by its existing native and ESP32-S3 jobs.

### Upstream mirror status

The ESPHome/LVGL base is synchronized from `alaltitov/Guition-ESP32-S3-4848S040` release branch `2026.8.2`.

The repository's only remote ESPHome external component is `alaltitov/esphome` for `i18n`. The upstream `dev` branch currently carries the i18n implementation required by this firmware; its HEAD was verified as `1b487af0ef26ff8e7908d34e415d99cc13fc1f98` on 2026-09-19. The dependency is pinned to that exact commit in `src/main.yaml` instead of floating on `@dev`, improving build reproducibility without switching to the incompatible `main` component revision.

The fork keeps the complete upstream file tree and adds the 3C/API/CI layer on top.
