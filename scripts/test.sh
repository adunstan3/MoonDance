#!/bin/bash
# Runs the unit tests on a warm watch simulator.
# Usage: scripts/test.sh [extra xcodebuild args, e.g. -only-testing:...]
set -euo pipefail
cd "$(dirname "$0")/.."

SIM_NAME="${SIM_NAME:-Apple Watch Ultra 4 (49mm)}"
DERIVED="${DERIVED:-build/DerivedData}"
SIM_ID=$(xcrun simctl list devices available | grep -F "$SIM_NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
if [ -z "$SIM_ID" ]; then
  echo "No simulator named $SIM_NAME" >&2
  exit 1
fi
xcrun simctl bootstatus "$SIM_ID" -b > /dev/null

COMMON=(-project "Moon Dance.xcodeproj" -scheme "Moon Dance Watch App" -destination "id=$SIM_ID" -derivedDataPath "$DERIVED")
xcodebuild build-for-testing "${COMMON[@]}" -quiet
xcodebuild test-without-building "${COMMON[@]}" -only-testing:"Moon Dance Watch AppTests" "$@"
