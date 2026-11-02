#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMP="$(mktemp -d)"
HOST_PID=""

cleanup() {
  if [ -n "$HOST_PID" ]; then
    kill "$HOST_PID" 2>/dev/null || true
    wait "$HOST_PID" 2>/dev/null || true
  fi
  rm -rf "$TEMP"
}
trap cleanup EXIT

# Compile exact production Swift networking and protocol used by Rebilium.
swiftc \
  "$ROOT/MacExecutor/BridgeWireProtocol.swift" \
  "$ROOT/MacExecutor/LocalBridgeClient.swift" \
  "$ROOT/Experiments/LoopbackHost/main.swift" \
  -o "$TEMP/RebiliumLoopbackProbe"

python3 "$ROOT/Experiments/LoopbackHost/host.py" \
  --port 0 --http-port 0 \
  --port-file "$TEMP/port" \
  --http-port-file "$TEMP/http-port" \
  --token-file "$TEMP/token" > "$TEMP/host.log" 2>&1 &
HOST_PID=$!

for attempt in $(seq 1 50); do
  if [ -s "$TEMP/port" ] && [ -s "$TEMP/http-port" ] && [ -s "$TEMP/token" ]; then break; fi
  if ! kill -0 "$HOST_PID" 2>/dev/null; then
    cat "$TEMP/host.log"
    exit 1
  fi
  sleep 0.1
done

if [ ! -s "$TEMP/token" ]; then
  cat "$TEMP/host.log"
  echo "Host did not start"
  exit 1
fi

# Before the Studio handshake, only the local test host exists.
"$TEMP/RebiliumLoopbackProbe" "$(cat "$TEMP/port")" studio:offline

# Emulate the *documented Studio plugin HTTP request* using real HTTP.
# The plugin itself must subsequently be tested manually in Roblox Studio.
python3 - "$TEMP/http-port" "$TEMP/token" <<'PY'
import http.client
import json
import pathlib
import sys

port = int(pathlib.Path(sys.argv[1]).read_text())
token = pathlib.Path(sys.argv[2]).read_text()
connection = http.client.HTTPConnection("127.0.0.1", port, timeout=3)
connection.request(
    "POST", "/v1/studio/hello",
    body=json.dumps({"version": 1, "client": "RebiliumStudioPlugin"}),
    headers={
        "Content-Type": "application/json",
        "X-Rebilium-Token": token,
    },
)
response = connection.getresponse()
assert response.status == 200, (response.status, response.read())
assert json.loads(response.read())["ok"] is True
connection.close()
PY

# Check the end-to-end bridge: HTTP heartbeat -> shared host state -> TCP ->
# production Swift protocol -> verified connected result.
"$TEMP/RebiliumLoopbackProbe" "$(cat "$TEMP/port")" studio:online
echo "Real HTTP-to-TCP Studio handshake integration verified."
