#!/bin/bash
# Relaunches the installed app once per argument set and screenshots each.
# Usage: scripts/shots.sh OUT_DIR name "launch args" [name "launch args"]...
set -euo pipefail
OUT="$1"; shift
SIM_NAME="${SIM_NAME:-Apple Watch Ultra 4 (49mm)}"
SIM_ID=$(xcrun simctl list devices available | grep -F "$SIM_NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
BUNDLE_ID="com.andrewdunstan.Moondance.watchkitapp"
while [ $# -ge 2 ]; do
  NAME="$1"; ARGS="$2"; shift 2
  xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" 2> /dev/null || true
  # shellcheck disable=SC2086
  xcrun simctl launch "$SIM_ID" "$BUNDLE_ID" $ARGS > /dev/null
  sleep "${SHOT_DELAY:-6}"
  xcrun simctl io "$SIM_ID" screenshot "$OUT/$NAME.png" > /dev/null 2>&1
  echo "$OUT/$NAME.png"
done
