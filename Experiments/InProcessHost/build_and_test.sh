#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT

# Explicit load-time dependency using an @executable_path install name.
# This is the same broad dylib-loading arrangement observed in the Delta IPA,
# but applied only to our own controlled test host.
clang -std=c11 -Wall -Wextra -Werror \
  -dynamiclib \
  -Wl,-install_name,@executable_path/librebilium_bridge.dylib \
  "$ROOT/RebiliumNativeBridge.c" \
  -o "$TEMP/librebilium_bridge.dylib"

clang -std=c11 -Wall -Wextra -Werror \
  "$ROOT/RebiliumTestHost.c" \
  -L"$TEMP" -lrebilium_bridge \
  -o "$TEMP/RebiliumTestHost"

if command -v otool >/dev/null; then
  otool -L "$TEMP/RebiliumTestHost" | grep -Fq '@executable_path/librebilium_bridge.dylib'
fi

"$TEMP/RebiliumTestHost"

# Ensure oversized payloads aren't implicitly accepted: compile and execute
# a second minimal client linked to the same native library.
cat > "$TEMP/check_limits.c" <<'EOF'
#include "RebiliumNativeBridge.h"
int main(void) {
    RebiliumBridgeResult result = {0};
    if (rebilium_submit_source("x", REBILIUM_MAX_SCRIPT_BYTES + 1, &result) != -2)
        return 1;
    if (rebilium_submit_source(0, 5, &result) != -3)
        return 2;
    if (rebilium_submit_source("", 0, &result) != 0)
        return 3;
    return result.abi_version != REBILIUM_BRIDGE_ABI_VERSION || !result.accepted;
}
EOF

clang -std=c11 -Wall -Wextra -Werror \
  -I"$ROOT" "$TEMP/check_limits.c" \
  -L"$TEMP" -lrebilium_bridge \
  -o "$TEMP/check_limits"
"$TEMP/check_limits"
echo "Native ABI tests passed."
