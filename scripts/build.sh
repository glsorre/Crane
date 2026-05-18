#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodebuild build \
    -project Crane.xcodeproj \
    -scheme Crane \
    -destination 'platform=macOS,arch=arm64'
