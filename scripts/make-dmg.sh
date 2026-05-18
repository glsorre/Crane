#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

: "${API_KEY_ID:?API_KEY_ID required}"
: "${API_ISSUER_ID:?API_ISSUER_ID required}"

APP="build/export/Right Crane.app"
API_KEY_PATH="${API_KEY_PATH:-/tmp/AuthKey.p8}"

if [ ! -e "$APP" ]; then
    echo "App not found at $APP" >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="build/RightCrane-${VERSION}.dmg"

if ! command -v create-dmg >/dev/null 2>&1; then
    brew install create-dmg
fi

rm -f "$DMG"

create-dmg \
    --volname "Right Crane ${VERSION}" \
    --window-size 540 380 \
    --icon-size 96 \
    --icon "Right Crane.app" 140 190 \
    --app-drop-link 400 190 \
    --no-internet-enable \
    "$DMG" \
    "$APP"

codesign --sign "Developer ID Application" --timestamp "$DMG"

xcrun notarytool submit "$DMG" \
    --key "$API_KEY_PATH" \
    --key-id "$API_KEY_ID" \
    --issuer "$API_ISSUER_ID" \
    --wait

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

rm -f "$API_KEY_PATH"
