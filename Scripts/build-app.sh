#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="VibeCodingBreath"
BUNDLE_ID="pro.nanzhi.VibeCodingBreath"
BUNDLE_DIR="$ROOT/Bundle"
INFO_PLIST="$BUNDLE_DIR/Info.plist"
ICONSET="$BUNDLE_DIR/Resources/AppIcon.iconset"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
    echo "Usage: $0 [debug|release]" >&2
    exit 2
fi

echo "[build-app] swift build ($CONFIG)"
if [[ "$CONFIG" == "release" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    BUILD_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
else
    swift build -c debug
    BUILD_DIR="$(swift build -c debug --show-bin-path)"
fi

APP_PATH="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_PATH/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "[build-app] assembling app bundle at $APP_PATH"
rm -rf "$APP_PATH"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BUILD_DIR/$APP_NAME" "$MACOS/$APP_NAME"
cp "$INFO_PLIST" "$CONTENTS/Info.plist"

if [[ -d "$ICONSET" ]] && ls "$ICONSET"/*.png >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
else
    echo "[build-app] (note) no PNGs in $ICONSET; skipping AppIcon.icns"
fi

# Copy SwiftPM-generated resource bundle(s) so NSLocalizedString + Bundle.module work.
shopt -s nullglob
for b in "$BUILD_DIR"/*.bundle; do
    base="$(basename "$b")"
    case "$base" in
        *_"$APP_NAME".bundle | "$APP_NAME"_"$APP_NAME".bundle)
            echo "[build-app] embedding resource bundle: $base"
            rm -rf "$RESOURCES/$base"
            cp -R "$b" "$RESOURCES/$base"
            if [[ "$CONFIG" == "release" ]]; then
                codesign --force --sign - "$RESOURCES/$base" || true
            fi
            ;;
    esac
done
shopt -u nullglob

echo "[build-app] done -> $APP_PATH"
