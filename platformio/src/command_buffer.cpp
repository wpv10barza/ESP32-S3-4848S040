#include "command_buffer.hpp"

#include <algorithm>

CommandBuffer::CommandBuffer(std::size_t capacity) : capacity_(capacity) {
  value_.reserve(capacity_);
}

bool CommandBuffer::set(const std::string& value) {
  if (value.size() >= capacity_) return false;
  value_ = value;
  return true;
}

bool CommandBuffer::insert(std::size_t cursor, char value) {
  if (value_.size() + 1 >= capacity_ || cursor > value_.size()) return false;
  value_.insert(value_.begin() + static_cast<std::ptrdiff_t>(cursor), value);
  return true;
}

bool CommandBuffer::erase(std::size_t cursor) {
  if (cursor >= value_.size()) return false;
  value_.erase(cursor, 1);
  return true;
}

bool CommandBuffer::backspace(std::size_t& cursor) {
  if (cursor == 0 || cursor > value_.size()) return false;
  value_.erase(cursor - 1, 1);
  --cursor;
  return true;
}

bool CommandBuffer::moveCursor(std::size_t& cursor, int delta) const {
  const auto old = cursor;
  if (delta < 0) {
    const auto amount = static_cast<std::size_t>(-delta);
    cursor = amount > cursor ? 0 : cursor - amount;
  } else {
    cursor = std::min(value_.size(), cursor + static_cast<std::size_t>(delta));
  }
  return old != cursor;
}
