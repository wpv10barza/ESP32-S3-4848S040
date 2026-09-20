#pragma once

#include <cstddef>
#include <string>

class CommandBuffer {
 public:
  explicit CommandBuffer(std::size_t capacity = 256);

  bool set(const std::string& value);
  bool insert(std::size_t cursor, char value);
  bool erase(std::size_t cursor);
  bool backspace(std::size_t& cursor);
  bool moveCursor(std::size_t& cursor, int delta) const;

  const std::string& value() const { return value_; }
  std::size_t size() const { return value_.size(); }
  std::size_t capacity() const { return capacity_; }

 private:
  std::size_t capacity_;
  std::string value_;
};
