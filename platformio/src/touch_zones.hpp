#pragma once

struct TouchZone {
  int x;
  int y;
  int width;
  int height;

  constexpr bool contains(int px, int py) const {
    return px >= x && px < x + width && py >= y && py < y + height;
  }
};

enum class TouchTarget {
  none,
  probar_wsl,
  enviar_3c,
};

inline TouchTarget hitTestMainZones(int x, int y) {
  constexpr TouchZone left{0, 360, 240, 120};
  constexpr TouchZone right{240, 360, 240, 120};
  if (left.contains(x, y)) return TouchTarget::probar_wsl;
  if (right.contains(x, y)) return TouchTarget::enviar_3c;
  return TouchTarget::none;
}
