#pragma once

#include "command_model.hpp"

#include <string>

struct ApiCommandResponse {
  bool ok{false};
  std::string command_id;
  std::string state;
  std::string detail;
};

class ICommandApi {
 public:
  virtual ~ICommandApi() = default;
  virtual ApiCommandResponse postCommand(const std::string& command) = 0;
  virtual ApiCommandResponse getCommand(const std::string& command_id) = 0;
};

class CommandFlow {
 public:
  explicit CommandFlow(ICommandApi& api) : api_(api) {}

  bool submit(const std::string& command);
  bool poll();

  const CommandRecord& record() const { return record_; }

 private:
  static CommandState mapState(const std::string& value);

  ICommandApi& api_;
  CommandRecord record_;
};
