"""Localhost-host unit tests. No Roblox process or remote network involved."""
import json
import socket
import threading
import unittest
import uuid

from host import BridgeHandler, LocalBridgeServer, MARKER, MAX_MESSAGE_BYTES


class LoopbackHostTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = LocalBridgeServer(("127.0.0.1", 0), BridgeHandler)
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


if __name__ == "__main__":
    unittest.main()
