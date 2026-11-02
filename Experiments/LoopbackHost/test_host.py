"""Localhost-host unit tests. No Roblox process or remote network involved."""
import json
import http.client
import socket
import threading
import unittest
import uuid

from host import (
    BridgeHandler, LocalBridgeServer, MARKER, MAX_MESSAGE_BYTES,
    StudioSessionState, StudioHTTPServer, STUDIO_CONNECTED,
    STUDIO_NOT_CONNECTED, STATUS_MARKER,
)


class LoopbackHostTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = LocalBridgeServer(("127.0.0.1", 0), BridgeHandler, studio_state=StudioSessionState(token="test-only-local-token"))
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=3)

    def exchange(self, payload):
        with socket.create_connection(self.server.server_address, timeout=2) as client:
            client.settimeout(2)
            client.sendall(payload + b"\n")
            client.shutdown(socket.SHUT_WR)
            result = bytearray()
            while True:
                part = client.recv(4096)
                if not part:
                    return bytes(result)
                result.extend(part)

    def test_pong_echoes_matching_uuid(self):
        request_id = str(uuid.uuid4()).upper()
        message = json.dumps({
            "version": 1, "requestID": request_id, "action": "ping", "payload": MARKER,
        }).encode("utf-8")
        reply = json.loads(self.exchange(message))
        self.assertEqual(reply["requestID"], request_id)
        self.assertEqual(reply["action"], "pong")
        self.assertEqual(reply["payload"], MARKER)
        self.assertEqual(reply["version"], 1)

    def test_rejects_execution_commands_and_unexpected_actions(self):
        for action in ["execute", "run", "status", "pong"]:
            message = json.dumps({
                "version": 1, "requestID": str(uuid.uuid4()),
                "action": action, "payload": "print('should never run')",
            }).encode("utf-8")
            self.assertEqual(self.exchange(message), b"")

    def test_rejects_wrong_version_malformed_uuid_and_oversize(self):
        base = {"version": 1, "requestID": str(uuid.uuid4()), "action": "ping", "payload": MARKER}
        for mutation in [
            {"version": 2},
            {"version": True},
            {"requestID": "not-a-uuid"},
            {"payload": "not-the-marker"},
        ]:
            message = json.dumps(base | mutation).encode("utf-8")
            self.assertEqual(self.exchange(message), b"")
        self.assertEqual(self.exchange(b"x" * (MAX_MESSAGE_BYTES + 1)), b"")

    def test_only_binds_to_loopback(self):
        self.assertEqual(self.server.server_address[0], "127.0.0.1")


class StudioPairingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.now = [100]
        cls.session = StudioSessionState(token="testing-token-012345678901234", clock=lambda: cls.now[0])
        cls.tcp = LocalBridgeServer(("127.0.0.1", 0), studio_state=cls.session)
        cls.http = StudioHTTPServer(("127.0.0.1", 0), cls.session)
        cls.threads = [
            threading.Thread(target=cls.tcp.serve_forever, daemon=True),
            threading.Thread(target=cls.http.serve_forever, daemon=True),
        ]
        for thread in cls.threads:
            thread.start()

    @classmethod
    def tearDownClass(cls):
        for server in [cls.tcp, cls.http]:
            server.shutdown()
            server.server_close()
        for thread in cls.threads:
            thread.join(timeout=3)

    def setUp(self):
        with self.session.lock:
            self.session.last_seen = None
        self.now[0] = 100

    def send_hello(self, token, body=None, method="POST"):
        connection = http.client.HTTPConnection(
            "127.0.0.1", self.http.server_address[1], timeout=2
        )
        try:
            connection.request(
                method, "/v1/studio/hello",
                body=body if body is not None else json.dumps({
                    "version": 1, "client": "RebiliumStudioPlugin",
                }),
                headers={
                    "Content-Type": "application/json",
                    "X-Rebilium-Token": token,
                },
            )
            response = connection.getresponse()
            return response.status, response.read()
        finally:
            connection.close()

    def status_over_tcp(self):
        frame = {
            "version": 1,
            "requestID": str(uuid.uuid4()),
            "action": "status",
            "payload": STATUS_MARKER,
        }
        with socket.create_connection(self.tcp.server_address, timeout=2) as sock:
            sock.sendall(json.dumps(frame).encode() + b"\n")
            result = bytearray()
            while not result.endswith(b"\n"):
                part = sock.recv(1024)
                if not part:
                    break
                result.extend(part)
        return json.loads(result)["payload"]

    def test_no_plugin_is_disconnected(self):
        self.assertEqual(self.status_over_tcp(), STUDIO_NOT_CONNECTED)

    def test_wrong_token_is_rejected_and_does_not_pair(self):
        code, _ = self.send_hello("wrong-token")
        self.assertEqual(code, 403)
        self.assertEqual(self.status_over_tcp(), STUDIO_NOT_CONNECTED)

    def test_studio_hello_updates_tcp_status_and_expires(self):
        code, data = self.send_hello(self.session.token)
        self.assertEqual(code, 200)
        self.assertTrue(json.loads(data)["ok"])
        self.assertEqual(self.status_over_tcp(), STUDIO_CONNECTED)
        self.now[0] += 31
        self.assertEqual(self.status_over_tcp(), STUDIO_NOT_CONNECTED)

    def test_rejects_invalid_message_and_non_post(self):
        code, _ = self.send_hello(
            self.session.token, body=json.dumps({"version": 1, "client": "unknown"})
        )
        self.assertEqual(code, 400)
        code, _ = self.send_hello(self.session.token, method="GET")
        self.assertEqual(code, 404)
        self.assertEqual(self.status_over_tcp(), STUDIO_NOT_CONNECTED)


if __name__ == "__main__":
    unittest.main()
