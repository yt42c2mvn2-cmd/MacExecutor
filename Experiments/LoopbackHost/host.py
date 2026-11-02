#!/usr/bin/env python3
"""A diagnostic-only TCP host for Rebilium.

Runs as a *separate* process and listens on 127.0.0.1 only.
Accepts only one protocol-v1 ping per connection; never runs any scripts,
touches Roblox, or opens a connection to the internet.
"""

import argparse
import json
import socket
import socketserver
import uuid
from pathlib import Path

DEFAULT_PORT = 37827
MAX_MESSAGE_BYTES = 4096
MARKER = "rebilium-local-ping-v1"


class BridgeHandler(socketserver.StreamRequestHandler):
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
            if request.get("action") != "ping" or request.get("payload") != MARKER:
                return

            request_id = request.get("requestID")
            if not isinstance(request_id, str):
                return
            uuid.UUID(request_id)  # reject malformed correlation IDs

            response = {
                "version": 1,
                "requestID": request_id,
                "action": "pong",
                "payload": MARKER,
            }
            response_bytes = json.dumps(response, separators=(",", ":")).encode("utf-8")
            if len(response_bytes) <= MAX_MESSAGE_BYTES:
                self.wfile.write(response_bytes + b"\n")
                self.wfile.flush()
                print("Handled local diagnostic ping:", request_id, flush=True)
        except (ValueError, KeyError, TypeError, OSError, TimeoutError, json.JSONDecodeError):
            # Unknown/invalid requests never cause code execution or traceback
            # leakage. They receive no diagnostic handshake.
            return


class LocalBridgeServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    parser = argparse.ArgumentParser(description="Rebilium diagnostic localhost host")
    parser.add_argument(
        "--port", type=int, default=DEFAULT_PORT,
        help="loopback port; use 0 only for test automation",
    )
    parser.add_argument(
        "--port-file", type=Path,
        help="write bound port to file for CI integration tests",
    )
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error("port must be between 0 and 65535")

    with LocalBridgeServer(("127.0.0.1", args.port), BridgeHandler) as server:
        host, port = server.server_address
        if args.port_file:
            args.port_file.write_text(str(port), encoding="utf-8")
        print(f"Rebilium local test host listening on {host}:{port}", flush=True)
        print("Ping-only diagnostics. No Roblox connection; press Ctrl+C to stop.", flush=True)
        try:
            server.serve_forever(poll_interval=0.1)
        except KeyboardInterrupt:
            print("Stopped.", flush=True)


if __name__ == "__main__":
    main()
