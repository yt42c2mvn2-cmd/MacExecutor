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

# Compile the actual production Swift client and protocol used by Rebilium.
swiftc \
  "$ROOT/MacExecutor/BridgeWireProtocol.swift" \
  "$ROOT/MacExecutor/LocalBridgeClient.swift" \
  "$ROOT/Experiments/LoopbackHost/main.swift" \
  -o "$TEMP/RebiliumLoopbackProbe"

python3 "$ROOT/Experiments/LoopbackHost/host.py" \
  --port 0 --port-file "$TEMP/port" > "$TEMP/host.log" 2>&1 &
HOST_PID=$!

for attempt in $(seq 1 50); do
  if [ -s "$TEMP/port" ]; then break; fi
  if ! kill -0 "$HOST_PID" 2>/dev/null; then
    cat "$TEMP/host.log"
    exit 1
  fi
  sleep 0.1
done

if [ ! -s "$TEMP/port" ]; then
  cat "$TEMP/host.log"
  echo "Host did not start"
  exit 1
fi

"$TEMP/RebiliumLoopbackProbe" "$(cat "$TEMP/port")"
echo "Real cross-process communication verified."
