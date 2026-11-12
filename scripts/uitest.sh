#!/bin/bash
# Runs the UI tests (slow: they launch the app) on the "Moondance Tests" simulator.
# Usage: scripts/uitest.sh [extra xcodebuild args]
set -euo pipefail
source "$(dirname "$0")/lock.sh"
cd "$(dirname "$0")/.."
DERIVED="${DERIVED:-build/DerivedData}"
SIM_ID=$("scripts/sim.sh")
COMMON=(-project "Moon Dance.xcodeproj" -scheme "Moon Dance Watch App" -destination "id=$SIM_ID" -derivedDataPath "$DERIVED")
xcodebuild build-for-testing "${COMMON[@]}" -quiet
xcodebuild test-without-building "${COMMON[@]}" -only-testing:"Moon Dance Watch AppUITests" "$@"
