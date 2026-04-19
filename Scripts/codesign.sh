#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="VibeCodingBreath"
ENTITLEMENTS="$ROOT/Bundle/VibeCodingBreath.entitlements"

APP_PATH="${1:-}"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application}"
PROFILE="${NOTARY_PROFILE:-}"

if [[ -z "$APP_PATH" ]]; then
    APP_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME.app"
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "codesign.sh: app bundle not found at $APP_PATH" >&2
    exit 1
fi

echo "[codesign] signing embedded bundles in $APP_PATH"
shopt -s nullglob
for b in "$APP_PATH/Contents/Resources"/*.bundle; do
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$b"
done
shopt -u nullglob

echo "[codesign] signing app bundle"
codesign --force --deep --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" \
    "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [[ -n "$PROFILE" ]]; then
    echo "[codesign] notarizing via keychain profile: $PROFILE"
    ZIP="$APP_PATH.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP_PATH" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
    rm -f "$ZIP"
    xcrun stapler staple "$APP_PATH"
    xcrun stapler validate "$APP_PATH"
else
    echo "[codesign] NOTARY_PROFILE not set; skipping notarization"
fi
