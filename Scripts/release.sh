#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="VibeCodingBreath"
VERSION=""
KEYCHAIN_PROFILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="${2:-}"; shift 2 ;;
        --keychain-profile)
            KEYCHAIN_PROFILE="${2:-}"; shift 2 ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2 ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 --version <x.y.z> [--keychain-profile <profile>]" >&2
    exit 2
fi

echo "[release] running swift test"
swift test

echo "[release] building release universal binary"
"$ROOT/Scripts/build-app.sh" release

APP_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME.app"

if [[ -n "$KEYCHAIN_PROFILE" ]]; then
    NOTARY_PROFILE="$KEYCHAIN_PROFILE" "$ROOT/Scripts/codesign.sh" "$APP_PATH"
else
    echo "[release] (note) --keychain-profile not passed; skipping sign/notarize"
fi

echo "[release] building DMG"
ARCH="universal"
DMG="$ROOT/dist/${APP_NAME}-${VERSION}-${ARCH}.dmg"
mkdir -p "$ROOT/dist"
rm -f "$DMG"

if command -v create-dmg >/dev/null 2>&1; then
    create-dmg \
        --volname "$APP_NAME $VERSION" \
        --window-pos 200 120 \
        --window-size 540 340 \
        --icon-size 96 \
        --icon "$APP_NAME.app" 140 150 \
        --app-drop-link 400 150 \
        --no-internet-enable \
        "$DMG" "$APP_PATH"
else
    echo "[release] create-dmg not installed; falling back to hdiutil"
    STAGE="$(mktemp -d)"
    cp -R "$APP_PATH" "$STAGE/"
    hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
    rm -rf "$STAGE"
fi

echo "[release] done -> $DMG"
