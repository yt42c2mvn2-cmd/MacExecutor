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
  "$ROOT/MacExecutor/StudioScriptTransfer.swift" \
  "$ROOT/Experiments/LoopbackHost/main.swift" \
  -o "$TEMP/RebiliumLoopbackProbe"

python3 -u "$ROOT/Experiments/LoopbackHost/host.py" \
  --port 0 --http-port 0 \
  --port-file "$TEMP/port" \
  --http-port-file "$TEMP/http-port" \
  --token-file "$TEMP/token" > "$TEMP/host.log" 2>&1 &
HOST_PID=$!

DEADLINE=$((SECONDS + 120))
while [ "$SECONDS" -lt "$DEADLINE" ]; do
  if [ -s "$TEMP/port" ] && [ -s "$TEMP/http-port" ] && [ -s "$TEMP/token" ]; then break; fi
  if ! kill -0 "$HOST_PID" 2>/dev/null; then
    cat "$TEMP/host.log"
    echo "Host exited before startup"
    exit 1
  fi
  sleep 0.2
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

# Test a complete *non-executing* source offer, preview and acknowledgement.
# The Studio UI approval itself requires a manual test inside Roblox Studio.
python3 - "$TEMP/http-port" "$TEMP/token" <<'PY'
import http.client
import json
import pathlib
import sys

port = int(pathlib.Path(sys.argv[1]).read_text())
token = pathlib.Path(sys.argv[2]).read_text()

def request(method, path, body=None):
    client = http.client.HTTPConnection("127.0.0.1", port, timeout=4)
    client.request(
        method, path, body=None if body is None else json.dumps(body),
        headers={"Content-Type": "application/json", "X-Rebilium-Token": token},
    )
    response = client.getresponse()
    result = response.status, json.loads(response.read())
    client.close()
    return result

code, offered = request("POST", "/v1/scripts/submit", {
    "version": 1, "title": "E2E_Test",
    "source": "return {message = 'safe preview'}",
})
assert code == 200 and offered["ok"], (code, offered)
code, preview = request("GET", "/v1/scripts/pending")
assert code == 200 and preview["pending"], (code, preview)
assert preview["source"] == "return {message = 'safe preview'}"
assert preview["id"] == offered["id"]
code, ack = request("POST", "/v1/scripts/ack", {
    "version": 1, "id": offered["id"],
})
assert code == 200 and ack["ok"]
code, missing = request("GET", "/v1/scripts/pending")
assert code == 200 and not missing["pending"]
print("Authorized script offer/preview/ack verified; nothing executed.")
PY

# Check the end-to-end bridge: HTTP heartbeat -> shared host state -> TCP ->
# production Swift protocol -> verified connected result.
"$TEMP/RebiliumLoopbackProbe" "$(cat "$TEMP/port")" studio:online
echo "Real HTTP-to-TCP Studio handshake integration verified."
