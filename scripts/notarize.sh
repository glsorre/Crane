#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

: "${API_KEY_ID:?API_KEY_ID required}"
: "${API_ISSUER_ID:?API_ISSUER_ID required}"
: "${API_KEY_B64:?API_KEY_B64 required}"

APP="build/export/Right Crane.app"
ZIP="build/RightCrane.zip"
API_KEY_PATH="${API_KEY_PATH:-/tmp/AuthKey.p8}"

if [ ! -e "$APP" ]; then
    echo "App not found at $APP" >&2
    exit 1
fi

echo "$API_KEY_B64" | base64 -d > "$API_KEY_PATH"
trap 'rm -f "$ZIP" "$API_KEY_PATH"' EXIT

ditto -c -k --keepParent "$APP" "$ZIP"

xcrun notarytool submit "$ZIP" \
    --key "$API_KEY_PATH" \
    --key-id "$API_KEY_ID" \
    --issuer "$API_ISSUER_ID" \
    --wait

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
