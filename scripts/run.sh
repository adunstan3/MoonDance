#!/bin/bash
# Builds, installs and launches the watch app on the simulator, optionally taking a screenshot.
# Usage: scripts/run.sh [shot.png] [launch args…]
set -euo pipefail
source "$(dirname "$0")/lock.sh"
cd "$(dirname "$0")/.."

DERIVED="${DERIVED:-build/DerivedData}"
BUNDLE_ID="com.andrewdunstan.Moondance.watchkitapp"
SIM_ID=$("$(dirname "$0")/sim.sh")

SHOT=""
if [ $# -gt 0 ] && [[ "$1" == *.png ]]; then
  SHOT="$1"
  shift
fi

xcodebuild build -project "Moon Dance.xcodeproj" -scheme "Moon Dance Watch App" \
  -destination "id=$SIM_ID" -derivedDataPath "$DERIVED" -quiet
APP="$DERIVED/Build/Products/Debug-watchsimulator/Moon Dance Watch App.app"
xcrun simctl install "$SIM_ID" "$APP"
xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" 2> /dev/null || true
xcrun simctl launch "$SIM_ID" "$BUNDLE_ID" "$@" > /dev/null

if [ -n "$SHOT" ]; then
  sleep "${SHOT_DELAY:-8}"
  xcrun simctl io "$SIM_ID" screenshot "$SHOT" > /dev/null 2>&1
  echo "Screenshot: $SHOT"
fi
