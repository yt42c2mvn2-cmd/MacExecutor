#!/usr/bin/env python3
"""Local Rebilium backend: diagnostic TCP and opt-in Roblox Studio handshake.

Both endpoints bind exclusively to IPv4 loopback. No script execution, file
mutation, Roblox Player attachment, injection, or outbound network traffic.
"""

import argparse
import hmac
import json
import secrets
import socketserver
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DEFAULT_PORT = 37827
DEFAULT_HTTP_PORT = 37828
MAX_MESSAGE_BYTES = 4096
MAX_HTTP_BODY_BYTES = 256
MAX_TRANSFER_BYTES = 65536
MAX_TRANSFER_JSON_BYTES = MAX_TRANSFER_BYTES + 4096
OFFER_LIFETIME_SECONDS = 600
MARKER = "rebilium-local-ping-v1"
STATUS_MARKER = "rebilium-studio-status-v1"
STUDIO_CONNECTED = "studio-connected"
STUDIO_NOT_CONNECTED = "studio-not-connected"


class StudioSessionState:
    """An ephemeral pairing token and a short-lived Studio presence lease."""

    def __init__(self, token=None, clock=time.monotonic):
        self.token = token or secrets.token_urlsafe(24)
        self.clock = clock
        self.lock = threading.Lock()
        self.last_seen = None
        self.pending = None

    def hello(self, token):
        if not hmac.compare_digest(token, self.token):
            return False
        with self.lock:
            self.last_seen = self.clock()
        return True

    def connected(self):
        with self.lock:
            return self.last_seen is not None and self.clock() - self.last_seen <= 30

    def offer_script(self, token, title, source):
        if not hmac.compare_digest(token, self.token):
            return None
        with self.lock:
            if self.last_seen is None or self.clock() - self.last_seen > 30:
                return None
            self.pending = {
                "id": str(uuid.uuid4()),
                "title": title,
                "source": source,
                "created": self.clock(),
            }
            return self.pending["id"]

    def pending_script(self, token):
        if not hmac.compare_digest(token, self.token):
            return None
        with self.lock:
            if not self.pending:
                return None
            if self.clock() - self.pending["created"] > OFFER_LIFETIME_SECONDS:
                self.pending = None
                return None
            return {k: self.pending[k] for k in ("id", "title", "source")}

    def acknowledge_import(self, token, script_id):
        if not hmac.compare_digest(token, self.token):
            return False
        with self.lock:
            if (self.pending is None or self.pending["id"] != script_id
                or self.clock() - self.pending["created"] > OFFER_LIFETIME_SECONDS):
                return False
            self.pending = None
            return True


class BridgeHandler(socketserver.StreamRequestHandler):
    """One line of protocol-v1 JSON per connection, reply and close."""

    def handle(self):
        self.request.settimeout(3)
        try:
            line = self.rfile.readline(MAX_MESSAGE_BYTES + 2)
            if not line.endswith(b"\n") or len(line) - 1 > MAX_MESSAGE_BYTES:
                return

            request = json.loads(line)
            if not isinstance(request, dict):
                return
            if type(request.get("version")) is not int or request["version"] != 1:
                return
            request_id = request.get("requestID")
            if not isinstance(request_id, str):
                return
            uuid.UUID(request_id)

            action = request.get("action")
            payload = request.get("payload")
            if action == "ping" and payload == MARKER:
                reply_action, reply_payload = "pong", MARKER
            elif action == "status" and payload == STATUS_MARKER:
                reply_action = "status"
                reply_payload = (
                    STUDIO_CONNECTED
                    if self.server.studio_state.connected()
                    else STUDIO_NOT_CONNECTED
                )
            else:
                return

            response = {
                "version": 1,
                "requestID": request_id,
                "action": reply_action,
                "payload": reply_payload,
            }
            response_bytes = json.dumps(response, separators=(",", ":")).encode("utf-8")
            if len(response_bytes) <= MAX_MESSAGE_BYTES:
                self.wfile.write(response_bytes + b"\n")
                self.wfile.flush()
                print(f"Handled local {action}: {request_id}", flush=True)
        except (ValueError, KeyError, TypeError, OSError, TimeoutError):
            return


class LocalBridgeServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, address, handler=BridgeHandler, studio_state=None):
        self.studio_state = studio_state or StudioSessionState()
        super().__init__(address, handler)


class StudioHTTPHandler(BaseHTTPRequestHandler):
    """Token-guarded Studio presence, pending script preview and acknowledgement."""

    def authenticated(self):
        token = self.headers.get("X-Rebilium-Token", "")
        if not hmac.compare_digest(token, self.server.studio_state.token):
            self.reply(403, {"error": "pairing-denied"})
            return None
        return token

    def read_json(self, limit):
        self.connection.settimeout(3)
        try:
            length = int(self.headers.get("Content-Length", "-1"))
        except ValueError:
            self.reply(400, {"error": "invalid-length"})
            return None
        if length > limit:
            self.reply(413, {"error": "invalid-size"})
            return None
        if length < 1:
            self.reply(400, {"error": "invalid-size"})
            return None
        try:
            message = json.loads(self.rfile.read(length))
        except (ValueError, UnicodeDecodeError, TimeoutError, OSError):
            self.reply(400, {"error": "invalid-json"})
            return None
        if (not isinstance(message, dict)
                or type(message.get("version")) is not int
                or message["version"] != 1):
            self.reply(400, {"error": "invalid-message"})
            return None
        return message

    def do_POST(self):
        if self.path not in (
            "/v1/studio/hello", "/v1/scripts/submit", "/v1/scripts/ack"
        ):
            self.reply(404, {"error": "not-found"})
            return
        token = self.authenticated()
        if token is None:
            return
        if self.path == "/v1/studio/hello":
            message = self.read_json(MAX_HTTP_BODY_BYTES)
            if message is None:
                return
            if message.get("client") != "RebiliumStudioPlugin":
                self.reply(400, {"error": "invalid-client"})
                return
            self.server.studio_state.hello(token)
            self.reply(200, {"version": 1, "ok": True, "heartbeatSeconds": 10})
        elif self.path == "/v1/scripts/submit":
            message = self.read_json(MAX_TRANSFER_JSON_BYTES)
            if message is None:
                return
            title, source = message.get("title"), message.get("source")
            if (not isinstance(title, str) or not 1 <= len(title) <= 80
                or not isinstance(source, str)
                or not 1 <= len(source.encode("utf-8")) <= MAX_TRANSFER_BYTES):
                self.reply(400, {"error": "invalid-script"})
                return
            script_id = self.server.studio_state.offer_script(token, title, source)
            if script_id is None:
                self.reply(409, {"error": "studio-not-paired"})
                return
            self.reply(200, {"version": 1, "ok": True, "id": script_id})
        else:
            message = self.read_json(MAX_HTTP_BODY_BYTES)
            if message is None:
                return
            script_id = message.get("id")
            if not isinstance(script_id, str):
                self.reply(400, {"error": "invalid-id"})
                return
            if not self.server.studio_state.acknowledge_import(token, script_id):
                self.reply(409, {"error": "unknown-or-expired-script"})
                return
            self.reply(200, {"version": 1, "ok": True})

    def do_GET(self):
        if self.path != "/v1/scripts/pending":
            self.reply(404, {"error": "not-found"})
            return
        token = self.authenticated()
        if token is None:
            return
        pending = self.server.studio_state.pending_script(token)
        if pending is None:
            self.reply(200, {"version": 1, "pending": False})
            return
        self.reply(200, {"version": 1, "pending": True, **pending})

    def reply(self, status, message):
        data = json.dumps(message, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        # Do not log pairing secrets, source contents, or request headers.
        return

class StudioHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address, studio_state):
        self.studio_state = studio_state
        super().__init__(address, StudioHTTPHandler)


def main():
    parser = argparse.ArgumentParser(description="Rebilium localhost bridge host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--http-port", type=int, default=DEFAULT_HTTP_PORT)
    parser.add_argument("--port-file", type=Path, help="TCP port output for CI")
    parser.add_argument("--http-port-file", type=Path, help="HTTP port output for CI")
    parser.add_argument("--token-file", type=Path, help="Ephemeral token output for CI")
    args = parser.parse_args()
    if not 0 <= args.port <= 65535 or not 0 <= args.http_port <= 65535:
        parser.error("ports must be between 0 and 65535")

    session = StudioSessionState()
    with LocalBridgeServer(("127.0.0.1", args.port), studio_state=session) as bridge:
        with StudioHTTPServer(("127.0.0.1", args.http_port), session) as studio_http:
            if args.token_file:
                # CI temporary directory; avoid world-readable credentials.
                args.token_file.touch(mode=0o600, exist_ok=True)
                args.token_file.chmod(0o600)
                args.token_file.write_text(session.token, encoding="utf-8")
            if args.port_file:
                args.port_file.write_text(str(bridge.server_address[1]), encoding="utf-8")
            if args.http_port_file:
                args.http_port_file.write_text(
                    str(studio_http.server_address[1]), encoding="utf-8"
                )

            http_thread = threading.Thread(
                target=studio_http.serve_forever, kwargs={"poll_interval": 0.1},
                daemon=True,
            )
            http_thread.start()
            print(f"Rebilium TCP diagnostics on 127.0.0.1:{bridge.server_address[1]}")
            print(f"Roblox Studio plugin handshake on 127.0.0.1:{studio_http.server_address[1]}")
            print(f"Studio pairing token: {session.token}", flush=True)
            print("Share this token only with your local Studio plugin. Ctrl+C to stop.")
            print("No Roblox Player access or Luau execution.", flush=True)
            try:
                bridge.serve_forever(poll_interval=0.1)
            except KeyboardInterrupt:
                print("Stopped.", flush=True)
            finally:
                studio_http.shutdown()
                http_thread.join(timeout=3)


if __name__ == "__main__":
    main()
