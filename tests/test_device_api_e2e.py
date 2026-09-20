import json
import threading
from http.client import HTTPConnection

from backend.device_api import make_server


def running_server():
    server = make_server()
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server


def request(server, method, path, payload=None):
    conn = HTTPConnection(server.server_address[0], server.server_address[1], timeout=5)
    body = json.dumps(payload).encode() if payload is not None else None
    headers = {"Content-Type": "application/json"} if body is not None else {}
    conn.request(method, path, body=body, headers=headers)
    response = conn.getresponse()
    data = json.loads(response.read().decode())
    status = response.status
    conn.close()
    return status, data


def stop(server):
    server.shutdown()
    server.server_close()


def test_health_is_not_physical_device_health():
    server = running_server()
    try:
        status, body = request(server, "GET", "/api/device/v1/health")
        assert status == 200
        assert body["status"] == "ok"
        assert body["physical_device"] == "unknown"
    finally:
        stop(server)


def test_pending_confirmation_polling_e2e():
    server = running_server()
    try:
        status, created = request(
            server,
            "POST",
            "/api/device/v1/commands",
            {
                "device_id": "ESP32-S3-4848S040",
                "command": "example command",
                "require_confirmation": True,
            },
        )
        assert status == 202
        assert created["state"] == "pending_confirmation"
        command_id = created["command_id"]

        status, pending = request(
            server, "GET", f"/api/device/v1/commands/{command_id}"
        )
        assert status == 200
        assert pending["state"] == "pending_confirmation"

        status, confirmed = request(
            server, "POST", f"/api/device/v1/commands/{command_id}/confirm", {}
        )
        assert status == 200
        assert confirmed["state"] == "applied"
        assert "transition:applied" in confirmed["audit"]

        status, final = request(
            server, "GET", f"/api/device/v1/commands/{command_id}"
        )
        assert status == 200
        assert final["state"] == "applied"
    finally:
        stop(server)


def test_empty_command_is_rejected():
    server = running_server()
    try:
        status, body = request(
            server,
            "POST",
            "/api/device/v1/commands",
            {"device_id": "ESP32-S3-4848S040", "command": ""},
        )
        assert status == 400
        assert body["error"] == "empty_command"
    finally:
        stop(server)
