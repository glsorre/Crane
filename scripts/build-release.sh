#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

: "${DEVELOPMENT_TEAM:?DEVELOPMENT_TEAM required}"

rm -rf build
mkdir -p build

cp scripts/ExportOptions.plist build/ExportOptions.plist
/usr/libexec/PlistBuddy -c "Set :teamID $DEVELOPMENT_TEAM" build/ExportOptions.plist

xcodebuild archive \
    -project Crane.xcodeproj \
    -scheme Crane \
    -destination 'generic/platform=macOS' \
    -archivePath build/RightCrane.xcarchive \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"

xcodebuild -exportArchive \
    -archivePath build/RightCrane.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist build/ExportOptions.plist
