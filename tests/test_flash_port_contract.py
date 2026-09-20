from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

flash = (ROOT / 'scripts/06_flash_monitor_guition.sh').read_text(encoding='utf-8')
verify = (ROOT / 'scripts/03_verify_guition.sh').read_text(encoding='utf-8')
physical = (ROOT / '.github/workflows/physical-validation.yml').read_text(encoding='utf-8')

assert '/dev/serial/by-id/*' in flash
assert '/dev/ttyACM*' in flash
assert '/dev/ttyUSB*' in flash
assert 'case "\${PORT}" in' in flash
assert '/dev/ttyS*' in flash
assert '--upload-port "\${PORT}"' in flash
assert '/dev/ttyS0' not in flash

assert flash.count('pio run -e') == 1
assert "test \"\$(grep -Fc 'github://alaltitov/esphome@' src/main.yaml)\" -eq 1" in verify

assert '/dev/ttyS*' in physical
assert 'test -c "\${SERIAL_PORT}"' in physical
assert '--upload-port "$SERIAL_PORT"' in physical

print('[OK] physical flash port contract')
