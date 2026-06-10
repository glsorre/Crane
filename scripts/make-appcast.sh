#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

: "${SPARKLE_ED_PRIVATE_KEY:?SPARKLE_ED_PRIVATE_KEY required}"

# Resolve Sparkle version from the SPM pin in the Xcode project.
# Override with SPARKLE_VERSION env var to skip the parse.
if [ -z "${SPARKLE_VERSION:-}" ]; then
    PBXPROJ="Crane.xcodeproj/project.pbxproj"
    if [ ! -f "$PBXPROJ" ]; then
        echo "Cannot find $PBXPROJ to resolve Sparkle version" >&2
        exit 1
    fi
    SPARKLE_VERSION=$(awk '
        /XCRemoteSwiftPackageReference "Sparkle" \*\/ =/ { found=1 }
        found && match($0, /minimumVersion = [0-9]+\.[0-9]+\.[0-9]+/) {
            s = substr($0, RSTART, RLENGTH)
            sub(/minimumVersion = /, "", s)
            print s
            exit
        }
    ' "$PBXPROJ")
    if [ -z "$SPARKLE_VERSION" ]; then
        echo "Could not parse Sparkle version from $PBXPROJ" >&2
        exit 1
    fi
    echo "Resolved Sparkle version from $PBXPROJ: $SPARKLE_VERSION"
fi

APP="build/export/Right Crane.app"
FEED_BASE_URL="${FEED_BASE_URL:-https://github.com/glsorre/Crane/releases/latest/download}"
RELEASE_NOTES_BASE_URL="${RELEASE_NOTES_BASE_URL:-https://github.com/glsorre/Crane/releases/tag}"

if [ ! -e "$APP" ]; then
    echo "App not found at $APP" >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")
MIN_SYS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$APP/Contents/Info.plist" 2>/dev/null || echo "26.0")

DMG="build/RightCrane-${VERSION}.dmg"
APPCAST="build/appcast.xml"

if [ ! -e "$DMG" ]; then
    echo "DMG not found at $DMG (run make-dmg.sh first)" >&2
    exit 1
fi

# --- Fetch Sparkle CLI tools (sign_update) ---
SPARKLE_DIR="${SPARKLE_DIR:-build/.sparkle}"
if [ ! -x "$SPARKLE_DIR/bin/sign_update" ]; then
    rm -rf "$SPARKLE_DIR"
    mkdir -p "$SPARKLE_DIR"
    TARBALL="$SPARKLE_DIR/sparkle.tar.xz"
    URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
    echo "Downloading Sparkle ${SPARKLE_VERSION} from $URL"
    curl -fsSL "$URL" -o "$TARBALL"
    tar -xJf "$TARBALL" -C "$SPARKLE_DIR"
    rm -f "$TARBALL"
fi

SIGN_UPDATE="$SPARKLE_DIR/bin/sign_update"
if [ ! -x "$SIGN_UPDATE" ]; then
    echo "sign_update not found at $SIGN_UPDATE" >&2
    exit 1
fi

# --- Sign DMG ---
PRIVATE_KEY_FILE="$(mktemp -t sparkle-ed).key"
trap 'rm -f "$PRIVATE_KEY_FILE"' EXIT
printf '%s' "$SPARKLE_ED_PRIVATE_KEY" > "$PRIVATE_KEY_FILE"

# sign_update outputs an attribute fragment like:
#   sparkle:edSignature="..." length="123456"
SIG_ATTRS=$("$SIGN_UPDATE" -f "$PRIVATE_KEY_FILE" "$DMG")
if [ -z "$SIG_ATTRS" ]; then
    echo "sign_update produced no output" >&2
    exit 1
fi

PUBDATE=$(LC_TIME=C date -u +"%a, %d %b %Y %H:%M:%S +0000")
ENCLOSURE_URL="${FEED_BASE_URL}/RightCrane-${VERSION}.dmg"
RELEASE_NOTES_URL="${RELEASE_NOTES_BASE_URL}/v${VERSION}"

cat > "$APPCAST" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Right Crane</title>
        <link>${FEED_BASE_URL}/appcast.xml</link>
        <description>Right Crane updates</description>
        <language>en</language>
        <item>
            <title>Version ${VERSION}</title>
            <pubDate>${PUBDATE}</pubDate>
            <sparkle:version>${BUILD}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>${MIN_SYS}</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>${RELEASE_NOTES_URL}</sparkle:releaseNotesLink>
            <enclosure url="${ENCLOSURE_URL}"
                       type="application/octet-stream"
                       ${SIG_ATTRS} />
        </item>
    </channel>
</rss>
EOF

echo "Wrote $APPCAST"
