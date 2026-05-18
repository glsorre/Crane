#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SWIFT_FORMAT="$(command -v swift-format || true)"
if [[ -z "$SWIFT_FORMAT" ]]; then
    SWIFT_FORMAT="$(xcrun --find swift-format 2>/dev/null || true)"
fi
if [[ -z "$SWIFT_FORMAT" ]]; then
    echo "error: swift-format not found (Xcode 14+ ships it; or brew install swift-format)" >&2
    exit 1
fi

STRICT="${LINT_STRICT:-0}"

if command -v swiftlint >/dev/null 2>&1; then
    echo "==> swiftlint"
    if [[ "$STRICT" == "1" ]]; then
        swiftlint --strict
    else
        swiftlint
    fi
else
    echo "warning: swiftlint not installed; skipping (brew install swiftlint)" >&2
fi

echo "==> swift-format lint ($SWIFT_FORMAT)"
if [[ "$STRICT" == "1" ]]; then
    "$SWIFT_FORMAT" lint --strict --recursive Crane CraneTests
else
    "$SWIFT_FORMAT" lint --recursive Crane CraneTests || true
fi

echo "OK"
