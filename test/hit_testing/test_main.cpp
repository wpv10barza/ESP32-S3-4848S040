#include <unity.h>
#include "touch_zones.hpp"

void test_left_and_right_zones_do_not_overlap() {
  TEST_ASSERT_EQUAL_INT(static_cast<int>(TouchTarget::probar_wsl),
                        static_cast<int>(hitTestMainZones(0, 360)));
  TEST_ASSERT_EQUAL_INT(static_cast<int>(TouchTarget::probar_wsl),
                        static_cast<int>(hitTestMainZones(239, 479)));
  TEST_ASSERT_EQUAL_INT(static_cast<int>(TouchTarget::enviar_3c),
                        static_cast<int>(hitTestMainZones(240, 360)));
  TEST_ASSERT_EQUAL_INT(static_cast<int>(TouchTarget::enviar_3c),
                        static_cast<int>(hitTestMainZones(479, 479)));
  TEST_ASSERT_EQUAL_INT(static_cast<int>(TouchTarget::none),
                        static_cast<int>(hitTestMainZones(480, 479)));
}

void setup() {}
void loop() {}
