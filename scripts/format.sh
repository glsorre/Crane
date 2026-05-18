#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SWIFT_FORMAT="$(command -v swift-format || true)"
if [[ -z "$SWIFT_FORMAT" ]]; then
    SWIFT_FORMAT="$(xcrun --find swift-format 2>/dev/null || true)"
fi
if [[ -z "$SWIFT_FORMAT" ]]; then
    echo "error: swift-format not found" >&2
    exit 1
fi

echo "==> swift-format format --in-place ($SWIFT_FORMAT)"
"$SWIFT_FORMAT" format --in-place --recursive Crane CraneTests

echo "OK"
