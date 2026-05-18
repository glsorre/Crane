#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PBXPROJ="Crane.xcodeproj/project.pbxproj"

usage() {
    cat <<EOF >&2
Usage: $0 (--patch | --minor | --major) [--dry-run] [--yes]

Bumps MARKETING_VERSION and CURRENT_PROJECT_VERSION in $PBXPROJ,
commits the change, and creates a v<version> tag.

  --patch       1.5.0 -> 1.5.1
  --minor       1.5.0 -> 1.6.0
  --major       1.5.0 -> 2.0.0
  --dry-run     Print planned changes only. No edits, no git ops.
  --yes         Skip interactive confirmation.

Push tag manually to trigger the release workflow:
  git push origin <branch> && git push origin v<new>
EOF
    exit 64
}

BUMP=""
DRY_RUN=0
ASSUME_YES=0

while [ $# -gt 0 ]; do
    case "$1" in
        --patch|--minor|--major)
            [ -z "$BUMP" ] || usage
            BUMP="${1#--}"
            ;;
        --dry-run) DRY_RUN=1 ;;
        --yes|-y)  ASSUME_YES=1 ;;
        -h|--help) usage ;;
        *) echo "Unknown arg: $1" >&2; usage ;;
    esac
    shift
done

[ -n "$BUMP" ] || usage
[ -f "$PBXPROJ" ] || { echo "Not found: $PBXPROJ" >&2; exit 1; }

if [ "$DRY_RUN" -eq 0 ]; then
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Working tree not clean. Commit or stash changes first." >&2
        exit 1
    fi
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "develop" ] && [ "$BRANCH" != "master" ] && [ "$BRANCH" != "main" ]; then
    echo "Warning: on branch '$BRANCH' (not develop/master/main)." >&2
    if [ "$ASSUME_YES" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
        read -r -p "Continue anyway? [y/N] " ans
        case "$ans" in y|Y|yes|YES) ;; *) echo "Aborted."; exit 1 ;; esac
    fi
fi

CURRENT_MV=$(grep -m1 -E '^[[:space:]]*MARKETING_VERSION = ' "$PBXPROJ" \
    | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/')
CURRENT_BN=$(grep -m1 -E '^[[:space:]]*CURRENT_PROJECT_VERSION = ' "$PBXPROJ" \
    | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);.*/\1/')

[ -n "$CURRENT_MV" ] || { echo "Could not read MARKETING_VERSION." >&2; exit 1; }
[ -n "$CURRENT_BN" ] || { echo "Could not read CURRENT_PROJECT_VERSION." >&2; exit 1; }

if [[ ! "$CURRENT_MV" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
    echo "Unexpected MARKETING_VERSION format: '$CURRENT_MV'" >&2
    exit 1
fi
if [[ ! "$CURRENT_BN" =~ ^[0-9]+$ ]]; then
    echo "Unexpected CURRENT_PROJECT_VERSION format: '$CURRENT_BN'" >&2
    exit 1
fi

IFS='.' read -r MAJ MIN PAT <<<"$CURRENT_MV"
MIN=${MIN:-0}
PAT=${PAT:-0}

case "$BUMP" in
    major) MAJ=$((MAJ + 1)); MIN=0; PAT=0 ;;
    minor) MIN=$((MIN + 1)); PAT=0 ;;
    patch) PAT=$((PAT + 1)) ;;
esac

NEW_MV="${MAJ}.${MIN}.${PAT}"
NEW_BN=$((CURRENT_BN + 1))
TAG="v${NEW_MV}"

echo "Bumping MARKETING_VERSION:       ${CURRENT_MV} -> ${NEW_MV}"
echo "Bumping CURRENT_PROJECT_VERSION: ${CURRENT_BN} -> ${NEW_BN}"
echo "Tag to create:                   ${TAG}"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "(dry-run: no files changed, no git ops performed)"
    exit 0
fi

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    echo "Tag ${TAG} already exists. Aborting." >&2
    exit 1
fi

if [ "$ASSUME_YES" -eq 0 ]; then
    read -r -p "Continue? [y/N] " ans
    case "$ans" in y|Y|yes|YES) ;; *) echo "Aborted."; exit 1 ;; esac
fi

EXPECTED_MV_COUNT=$(grep -cE "^[[:space:]]*MARKETING_VERSION = ${CURRENT_MV};" "$PBXPROJ" || true)
EXPECTED_BN_COUNT=$(grep -cE "^[[:space:]]*CURRENT_PROJECT_VERSION = ${CURRENT_BN};" "$PBXPROJ" || true)

if [ "$EXPECTED_MV_COUNT" -eq 0 ] || [ "$EXPECTED_BN_COUNT" -eq 0 ]; then
    echo "No matching version lines found. Aborting." >&2
    exit 1
fi

sed -i '' -E \
    -e "s/^([[:space:]]*)MARKETING_VERSION = ${CURRENT_MV};/\1MARKETING_VERSION = ${NEW_MV};/" \
    -e "s/^([[:space:]]*)CURRENT_PROJECT_VERSION = ${CURRENT_BN};/\1CURRENT_PROJECT_VERSION = ${NEW_BN};/" \
    "$PBXPROJ"

ACTUAL_MV_COUNT=$(grep -cE "^[[:space:]]*MARKETING_VERSION = ${NEW_MV};" "$PBXPROJ" || true)
ACTUAL_BN_COUNT=$(grep -cE "^[[:space:]]*CURRENT_PROJECT_VERSION = ${NEW_BN};" "$PBXPROJ" || true)

if [ "$ACTUAL_MV_COUNT" -ne "$EXPECTED_MV_COUNT" ] || [ "$ACTUAL_BN_COUNT" -ne "$EXPECTED_BN_COUNT" ]; then
    echo "Post-edit verification failed (MV ${ACTUAL_MV_COUNT}/${EXPECTED_MV_COUNT}, BN ${ACTUAL_BN_COUNT}/${EXPECTED_BN_COUNT}). Restoring." >&2
    git checkout -- "$PBXPROJ"
    exit 1
fi

git add "$PBXPROJ"
git commit -m "chore: bump version to ${TAG}"
git tag "${TAG}"

echo
echo "Done. To trigger the release workflow:"
echo "  git push origin ${BRANCH} && git push origin ${TAG}"
