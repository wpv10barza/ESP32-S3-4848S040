#include "api_flow.hpp"

#ifdef ARDUINO

#include <HTTPClient.h>
#include <WiFi.h>

#ifndef WIFI_SSID
#define WIFI_SSID "CHANGE_ME"
#endif
#ifndef WIFI_PASSWORD
#define WIFI_PASSWORD "CHANGE_ME"
#endif
#ifndef DEVICE_API_BASE_URL
#define DEVICE_API_BASE_URL "http://127.0.0.1:8000"
#endif

namespace {
class Esp32Api final : public ICommandApi {
 public:
  explicit Esp32Api(const char* base_url) : base_url_(base_url) {}

  ApiCommandResponse postCommand(const std::string& command) override {
    HTTPClient http;
    http.begin(base_url_ + "/api/device/v1/commands");
    http.addHeader("Content-Type", "application/json");
    const std::string payload =
        "{\"device_id\":\"ESP32-S3-4848S040\",\"command\":\"" +
        escape(command) + "\",\"require_confirmation\":true}";
    const int code = http.POST(payload.c_str());
    const String body = http.getString();
    http.end();

    return parse(code, body);
  }

  ApiCommandResponse getCommand(const std::string& command_id) override {
    HTTPClient http;
    http.begin(base_url_ + "/api/device/v1/commands/" + command_id);
    const int code = http.GET();
    const String body = http.getString();
    http.end();

    return parse(code, body);
  }

 private:
  std::string base_url_;

  static std::string escape(const std::string& value) {
    std::string out;
    for (char c : value) {
      if (c == '\\' || c == '"') out.push_back('\\');
      out.push_back(c);
    }
    return out;
  }

  static std::string field(const String& body, const char* key) {
    const std::string text = body.c_str();
    const std::string needle = std::string("\"") + key + "\":\"";
    const auto start = text.find(needle);
    if (start == std::string::npos) return {};
    const auto value_start = start + needle.size();
    const auto value_end = text.find('"', value_start);
    if (value_end == std::string::npos) return {};
    return text.substr(value_start, value_end - value_start);
  }

  static ApiCommandResponse parse(int status, const String& body) {
    ApiCommandResponse response;
    response.ok = status >= 200 && status < 300;
    response.command_id = field(body, "command_id");
    response.state = field(body, "state");
    response.detail = field(body, "detail");
    if (!response.ok && response.detail.empty()) response.detail = "HTTP request failed";
    return response;
  }
};

Esp32Api api(DEVICE_API_BASE_URL);
CommandFlow flow(api);
unsigned long next_poll_ms = 0;

void print_state() {
  Serial.printf("command_id=%s state=%s detail=%s\\n",
                flow.record().command_id.c_str(),
                to_string(flow.record().state),
                flow.record().detail.c_str());
}
}

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\\nESP32-S3-4848S040 PlatformIO validation firmware");

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Wi-Fi connecting");
  const unsigned long started = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - started < 15000UL) {
    delay(250);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Wi-Fi OK: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("Wi-Fi ERROR");
  }
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) return;

  if (flow.record().command_id.empty()) {
    // No automatic command is sent. The device must only submit a real
    // command from the application UI, after empty-command validation.
    delay(50);
    return;
  }

  if (millis() >= next_poll_ms &&
      flow.record().state == CommandState::pending_confirmation) {
    flow.poll();
    print_state();
    next_poll_ms = millis() + 2500UL;
  }
}

#else

// Native PlatformIO tests provide the executable entry point.

#endif
