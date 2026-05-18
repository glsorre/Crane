#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodebuild test \
    -project Crane.xcodeproj \
    -scheme Crane \
    -destination 'platform=macOS,arch=arm64' \
    -resultBundlePath build/TestResults.xcresult \
    | xcbeautify 2>/dev/null || xcodebuild test \
    -project Crane.xcodeproj \
    -scheme Crane \
    -destination 'platform=macOS,arch=arm64' \
    -resultBundlePath build/TestResults.xcresult
