#pragma once

#include <string>

enum class CommandState {
  idle,
  submitting,
  pending_confirmation,
  applied,
  rejected,
  error,
};

struct CommandRecord {
  std::string command;
  std::string command_id;
  std::string detail;
  CommandState state{CommandState::idle};
};

inline const char* to_string(CommandState state) {
  switch (state) {
    case CommandState::idle: return "idle";
    case CommandState::submitting: return "submitting";
    case CommandState::pending_confirmation: return "pending_confirmation";
    case CommandState::applied: return "applied";
    case CommandState::rejected: return "rejected";
    case CommandState::error: return "error";
  }
  return "error";
}
