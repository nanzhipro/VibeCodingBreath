#!/usr/bin/env bash
# Codesign the assembled .app with a Developer ID identity.
# Usage:
#   Scripts/codesign.sh [debug|release] --identity "Developer ID Application: <Name> (TEAMID)"
#   CODESIGN_IDENTITY=... Scripts/codesign.sh [debug|release]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="release"
IDENTITY="${CODESIGN_IDENTITY:-}"

# Backwards-compat positional args: [config] [identity]
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity) IDENTITY="$2"; shift 2 ;;
    -h|--help)  sed -n '2,7p' "$0"; exit 0 ;;
    *)          POSITIONAL+=("$1"); shift ;;
  esac
done
[[ ${#POSITIONAL[@]} -ge 1 ]] && CONFIG="${POSITIONAL[0]}"
[[ ${#POSITIONAL[@]} -ge 2 && -z "$IDENTITY" ]] && IDENTITY="${POSITIONAL[1]}"

APP_DIR=".build/$CONFIG/VibeCodingBreath.app"
ENTITLEMENTS="Bundle/VibeCodingBreath.entitlements"

if [[ -z "$IDENTITY" ]]; then
  echo "error: codesign identity not provided. Use --identity \"...\" or set CODESIGN_IDENTITY env." >&2
  exit 2
fi

if [[ ! -d "$APP_DIR" ]]; then
  echo "App not found at $APP_DIR — run Scripts/build-app.sh $CONFIG first" >&2
  exit 1
fi

if [[ ! -f "$ENTITLEMENTS" ]]; then
  echo "Missing $ENTITLEMENTS" >&2
  exit 1
fi

echo "==> signing nested bundles"
for nested in "$APP_DIR"/Contents/MacOS/*.bundle; do
  [[ -e "$nested" ]] || continue
  codesign --force --options runtime --timestamp \
    --sign "$IDENTITY" "$nested"
done

echo "==> signing $APP_DIR"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" "$APP_DIR"

echo "==> verifying"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
codesign -dv --verbose=2 "$APP_DIR" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier|Signature"
echo "==> done"
