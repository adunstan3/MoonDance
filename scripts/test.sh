#!/bin/bash
# Runs the unit tests on a warm watch simulator.
# Usage: scripts/test.sh [extra xcodebuild args, e.g. -only-testing:...]
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="${DERIVED:-build/DerivedData}"
SIM_ID=$("$(dirname "$0")/sim.sh")

COMMON=(-project "Moon Dance.xcodeproj" -scheme "Moon Dance Watch App" -destination "id=$SIM_ID" -derivedDataPath "$DERIVED")
xcodebuild build-for-testing "${COMMON[@]}" -quiet
xcodebuild test-without-building "${COMMON[@]}" -only-testing:"Moon Dance Watch AppTests" "$@"
