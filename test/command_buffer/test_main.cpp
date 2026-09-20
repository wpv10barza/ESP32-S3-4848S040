#include <unity.h>
#include "command_buffer.hpp"

void test_insert_and_backspace() {
  CommandBuffer buffer(16);
  TEST_ASSERT_TRUE(buffer.set("abc"));
  std::size_t cursor = 2;
  TEST_ASSERT_TRUE(buffer.insert(cursor, 'X'));
  TEST_ASSERT_EQUAL_STRING("abXc", buffer.value().c_str());
  ++cursor;
  TEST_ASSERT_TRUE(buffer.backspace(cursor));
  TEST_ASSERT_EQUAL_STRING("abc", buffer.value().c_str());
  TEST_ASSERT_EQUAL_UINT32(2, cursor);
}

void test_capacity_guard() {
  CommandBuffer buffer(4);
  TEST_ASSERT_TRUE(buffer.set("abc"));
  TEST_ASSERT_FALSE(buffer.insert(3, 'd'));
  TEST_ASSERT_EQUAL_STRING("abc", buffer.value().c_str());
}

void test_cursor_bounds() {
  CommandBuffer buffer(8);
  TEST_ASSERT_TRUE(buffer.set("abcd"));
  std::size_t cursor = 0;
  TEST_ASSERT_FALSE(buffer.moveCursor(cursor, -1));
  TEST_ASSERT_TRUE(buffer.moveCursor(cursor, 2));
  TEST_ASSERT_EQUAL_UINT32(2, cursor);
  TEST_ASSERT_TRUE(buffer.moveCursor(cursor, 100));
  TEST_ASSERT_EQUAL_UINT32(4, cursor);
}

void setup() {}
void loop() {}
