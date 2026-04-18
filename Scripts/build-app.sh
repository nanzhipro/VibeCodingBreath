#!/usr/bin/env bash
# Assemble a runnable .app from the SwiftPM executable + Bundle/Info.plist.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-debug}"
APP_NAME="VibeCodingBreath"
BUILD_DIR=".build/$CONFIG"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_PATH="$BUILD_DIR/$APP_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "executable not found at $BIN_PATH" >&2
  exit 1
fi

# Locate SwiftPM-emitted resource bundle (named "<pkg>_<target>.bundle")
RES_BUNDLE=$(ls -d "$BUILD_DIR"/*VibeCodingBreath*.bundle 2>/dev/null | head -n 1 || true)

echo "==> assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "Bundle/Info.plist" "$APP_DIR/Contents/Info.plist"

if [[ -d "Bundle/Resources" ]]; then
  cp -R "Bundle/Resources"/. "$APP_DIR/Contents/Resources/"
fi

if [[ -n "$RES_BUNDLE" && -d "$RES_BUNDLE" ]]; then
  # Copy the contents of the resource bundle into Contents/Resources
  cp -R "$RES_BUNDLE"/* "$APP_DIR/Contents/Resources/" || true
  # Also copy the bundle itself (SwiftPM Bundle.module needs it next to binary)
  cp -R "$RES_BUNDLE" "$APP_DIR/Contents/MacOS/"
fi

# Ad-hoc sign so Gatekeeper / TCC treats it as a stable identity.
# Sign nested bundle first, then the app.
if [[ -d "$APP_DIR/Contents/MacOS"/*VibeCodingBreath*.bundle ]] 2>/dev/null; then :; fi
for nested in "$APP_DIR"/Contents/MacOS/*.bundle; do
  [[ -e "$nested" ]] || continue
  codesign --force --sign - --timestamp=none "$nested" >/dev/null
done
codesign --force --sign - --timestamp=none "$APP_DIR" >/dev/null

echo "==> built $APP_DIR"
