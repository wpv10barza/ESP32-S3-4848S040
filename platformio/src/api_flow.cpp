#include "api_flow.hpp"

CommandState CommandFlow::mapState(const std::string& value) {
  if (value == "pending_confirmation") return CommandState::pending_confirmation;
  if (value == "applied") return CommandState::applied;
  if (value == "rejected") return CommandState::rejected;
  if (value == "error" || value == "failed") return CommandState::error;
  return CommandState::error;
}

bool CommandFlow::submit(const std::string& command) {
  if (command.empty()) {
    record_ = {};
    record_.state = CommandState::error;
    record_.detail = "empty command blocked";
    return false;
  }

  record_ = {};
  record_.command = command;
  record_.state = CommandState::submitting;

  const auto response = api_.postCommand(command);
  if (!response.ok || response.command_id.empty()) {
    record_.state = CommandState::error;
    record_.detail = response.detail.empty() ? "POST failed" : response.detail;
    return false;
  }

  record_.command_id = response.command_id;
  record_.detail = response.detail;
  record_.state = mapState(response.state);
  return record_.state == CommandState::pending_confirmation;
}

bool CommandFlow::poll() {
  if (record_.command_id.empty()) return false;

  const auto response = api_.getCommand(record_.command_id);
  if (!response.ok) {
    record_.state = CommandState::error;
    record_.detail = response.detail.empty() ? "polling failed" : response.detail;
    return false;
  }

  record_.detail = response.detail;
  record_.state = mapState(response.state);
  return record_.state != CommandState::error;
}
