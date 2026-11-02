#!/usr/bin/env bash
set -euo pipefail

# Read-only inventory of the actual installed Roblox Player bundle.
# No process attachment, patching, code injection, or security changes.

usage() {
  echo 'Usage: bash Experiments/RobloxPlayerInspection/inspect.sh [path-to-Roblox.app]'
}

if (( $# > 0 )) && [[ "$1" == '--help' ]]; then
  usage
  exit 0
fi
if [[ "$(uname -s)" != 'Darwin' ]]; then
  echo 'macOS is required for signing and Mach-O inspection.' >&2
  exit 1
fi

read_bundle_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null || true
}
resolve_player() {
  local path="$1" candidate identifier
  for candidate in "$path" "$path/Contents/MacOS/Roblox.app"; do
    [[ -f "$candidate/Contents/Info.plist" ]] || continue
    identifier="$(read_bundle_value "$candidate" CFBundleIdentifier)"
    if [[ "$(echo "$identifier" | tr '[:upper:]' '[:lower:]')" == 'com.roblox.robloxplayer' ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

player=''
if (( $# > 1 )); then
  usage >&2
  exit 2
elif (( $# == 1 )); then
  if ! player="$(resolve_player "$1")"; then
    echo "Could not resolve a Roblox Player bundle from $1" >&2
    exit 1
  fi
else
  for root in '/Applications' "$HOME/Applications"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' found; do
      if player="$(resolve_player "$found")"; then
        break 2
      fi
    done < <(find "$root" -maxdepth 8 -type d -name Roblox.app -print0 2>/dev/null)
  done
fi
if [[ -z "$player" ]]; then
  echo 'Roblox Player not found. Supply an explicit Roblox.app path.' >&2
  exit 1
fi

bundle_id="$(read_bundle_value "$player" CFBundleIdentifier)"
executable_name="$(read_bundle_value "$player" CFBundleExecutable)"
binary="$player/Contents/MacOS/$executable_name"
if [[ -z "$executable_name" || ! -f "$binary" ]]; then
  echo 'Player bundle was found, but its declared executable is missing.' >&2
  exit 1
fi

printf '%s\n' '===== Rebilium: read-only Roblox Player binary audit ====='
printf 'Player bundle: %s\n' "$player"
printf 'Bundle ID: %s\n' "$bundle_id"
printf 'Executable: %s\n' "$binary"
printf 'Host architecture: %s\n' "$(uname -m)"
echo '--- Mach-O / supported architectures ---'
file "$binary"
if command -v lipo >/dev/null; then lipo -archs "$binary" 2>&1 || true; fi
echo '--- macOS code-signing metadata ---'
if command -v codesign >/dev/null; then
  codesign -dv --verbose=4 "$player" 2>&1 |
    grep -E '^(Executable=|Identifier=|Format=|CodeDirectory|Authority=|TeamIdentifier=|Timestamp=|Flags=|Runtime Version=|Sealed Resources=)' || true
  echo '--- Declared entitlements (if any) ---'
  codesign -d --entitlements :- "$player" 2>&1 || true
  echo '--- Signature verification (read-only) ---'
  codesign --verify --verbose=2 "$player" 2>&1 || true
fi
echo '--- Existing load-time library dependencies ---'
if command -v otool >/dev/null; then
  otool -L "$binary" 2>&1 | head -n 65
else
  echo 'otool unavailable; install the Xcode Command Line Tools.'
fi
echo '===== End of report ====='
echo 'No running process was accessed, no files were modified, and no code was injected.'
