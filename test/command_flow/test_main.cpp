#include <unity.h>
#include "api_flow.hpp"

class FakeApi final : public ICommandApi {
 public:
  ApiCommandResponse post_response{true, "cmd-1", "pending_confirmation", "awaiting human confirmation"};
  ApiCommandResponse poll_response{true, "cmd-1", "applied", "confirmed and applied"};
  bool post_called{false};
  bool poll_called{false};

  ApiCommandResponse postCommand(const std::string&) override {
    post_called = true;
    return post_response;
  }

  ApiCommandResponse getCommand(const std::string&) override {
    poll_called = true;
    return poll_response;
  }
};

void test_empty_command_blocked() {
  FakeApi api;
  CommandFlow flow(api);
  TEST_ASSERT_FALSE(flow.submit(""));
  TEST_ASSERT_EQUAL_STRING("error", to_string(flow.record().state));
  TEST_ASSERT_FALSE(api.post_called);
}

void test_pending_confirmation_and_apply() {
  FakeApi api;
  CommandFlow flow(api);
  TEST_ASSERT_TRUE(flow.submit("restart service"));
  TEST_ASSERT_TRUE(api.post_called);
  TEST_ASSERT_EQUAL_STRING("pending_confirmation", to_string(flow.record().state));

  TEST_ASSERT_TRUE(flow.poll());
  TEST_ASSERT_TRUE(api.poll_called);
  TEST_ASSERT_EQUAL_STRING("applied", to_string(flow.record().state));
}

void test_rejected_and_failed_paths() {
  FakeApi api;
  CommandFlow flow(api);
  TEST_ASSERT_TRUE(flow.submit("do thing"));

  api.poll_response.state = "rejected";
  TEST_ASSERT_TRUE(flow.poll());
  TEST_ASSERT_EQUAL_STRING("rejected", to_string(flow.record().state));

  api.poll_response.state = "failed";
  TEST_ASSERT_FALSE(flow.poll());
  TEST_ASSERT_EQUAL_STRING("error", to_string(flow.record().state));
}

void setup() {}
void loop() {}
