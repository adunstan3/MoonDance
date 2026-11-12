#!/bin/bash
# Archives the app (Release, any watchOS device) and uploads it to App Store
# Connect for TestFlight (Internal Only). Bump CURRENT_PROJECT_VERSION first:
# App Store Connect rejects a build number it has already seen.
# Uses the Apple ID signed in to Xcode (Settings › Accounts) for signing and upload.
# Usage: scripts/release.sh
set -euo pipefail
source "$(dirname "$0")/lock.sh"
cd "$(dirname "$0")/.."

ARCHIVE=build/Moondance.xcarchive
rm -rf "$ARCHIVE" build/Export
xcodebuild archive -project "Moon Dance.xcodeproj" -scheme "Moon Dance Watch App" -configuration Release \
  -destination 'generic/platform=watchOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates -quiet
VERSION=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" "$ARCHIVE/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" "$ARCHIVE/Info.plist")
echo "Archived Moondance $VERSION ($BUILD); uploading…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath build/Export -allowProvisioningUpdates 2>&1 | grep -E "error|Upload succeeded|EXPORT (SUCCEEDED|FAILED)"
echo "Uploaded $VERSION ($BUILD). It shows in App Store Connect › TestFlight after processing."
