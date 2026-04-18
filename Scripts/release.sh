#!/usr/bin/env bash
# release.sh — full release pipeline: build → assemble .app → codesign →
# create DMG → sign DMG → notarize → staple.
#
# All credentials & identities MUST come from CLI flags or environment
# variables; nothing is hard-coded in this script.
#
# Required for codesign:
#   --identity "Developer ID Application: <Name> (TEAMID)"   or  CODESIGN_IDENTITY
#
# Notarization (one of):
#   --keychain-profile <name>                                or  NOTARY_KEYCHAIN_PROFILE
#     (created with: xcrun notarytool store-credentials …)
#   --apple-id <id> --app-password <pw> --team-id <team>     or  APPLE_ID / APPLE_APP_PASSWORD / APPLE_TEAM_ID
#   --skip-notarize                                          to skip entirely
#
# Other flags:
#   --version <X.Y.Z>     stamp CFBundleShortVersionString / CFBundleVersion
#   --config <release|debug>   default: release
#
# Usage examples:
#   Scripts/release.sh \
#     --identity "Developer ID Application: Acme Co. (ABCDE12345)" \
#     --keychain-profile vcb-notary \
#     --version 0.1.0
#
#   CODESIGN_IDENTITY="…" APPLE_ID=… APPLE_APP_PASSWORD=… APPLE_TEAM_ID=… \
#     Scripts/release.sh --version 0.1.0
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ---------- defaults (env-overridable, no project-specific hard-codes) ----------
CONFIG="release"
APP_NAME="VibeCodingBreath"
IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-false}"
VERSION=""

# ---------- args ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --identity)            IDENTITY="$2"; shift 2 ;;
        --version)             VERSION="$2"; shift 2 ;;
        --config)              CONFIG="$2"; shift 2 ;;
        --keychain-profile)    NOTARY_KEYCHAIN_PROFILE="$2"; shift 2 ;;
        --apple-id)            APPLE_ID="$2"; shift 2 ;;
        --app-password)        APPLE_APP_PASSWORD="$2"; shift 2 ;;
        --team-id)             APPLE_TEAM_ID="$2"; shift 2 ;;
        --skip-notarize)       SKIP_NOTARIZE="true"; shift ;;
        -h|--help)
            sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

ARCH="$(uname -m)"
DIST_DIR="dist"
BUILD_DIR=".build/${CONFIG}"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

step()  { printf "\n\033[1;32m==> %s\033[0m\n" "$*"; }
warn()  { printf "\033[1;33m!! %s\033[0m\n" "$*" >&2; }
fail()  { printf "\033[1;31mxx %s\033[0m\n" "$*" >&2; exit 1; }

# ---------- prereqs ----------
step "Checking prerequisites"
command -v swift     >/dev/null || fail "swift not found"
command -v xcrun     >/dev/null || fail "xcrun not found"
command -v hdiutil   >/dev/null || fail "hdiutil not found"
command -v ditto     >/dev/null || fail "ditto not found"
command -v codesign  >/dev/null || fail "codesign not found"
xcrun --find notarytool >/dev/null || fail "notarytool not found (install Xcode CLT)"
xcrun --find stapler    >/dev/null || fail "stapler not found"

if [[ -z "$IDENTITY" ]]; then
    fail "Codesign identity not provided. Pass --identity \"…\" or set CODESIGN_IDENTITY env."
fi
if ! security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
    fail "Codesign identity not found in keychain: $IDENTITY"
fi
echo "identity: $IDENTITY"

# Determine notarization mode
NOTARY_MODE="none"
if [[ "$SKIP_NOTARIZE" != "true" ]]; then
    if [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]]; then
        NOTARY_MODE="profile"
    elif [[ -n "$APPLE_ID" && -n "$APPLE_APP_PASSWORD" && -n "$APPLE_TEAM_ID" ]]; then
        NOTARY_MODE="creds"
    else
        warn "No notarization credentials (NOTARY_KEYCHAIN_PROFILE or APPLE_ID/APPLE_APP_PASSWORD/APPLE_TEAM_ID); skipping notarization."
    fi
fi
echo "notarization: $NOTARY_MODE"

# ---------- 1. tests ----------
step "swift test"
swift test 2>&1 | tail -5

# ---------- 2. build .app ----------
step "Build & assemble .app ($CONFIG)"
"$ROOT/Scripts/build-app.sh" "$CONFIG"

# Optional: stamp version
if [[ -n "$VERSION" ]]; then
    step "Stamping version $VERSION"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" \
        "$APP_DIR/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" \
        "$APP_DIR/Contents/Info.plist"
fi

VERSION_VALUE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
echo "version: $VERSION_VALUE"

# ---------- 3. codesign .app ----------
step "Codesign .app with Developer ID + hardened runtime"
"$ROOT/Scripts/codesign.sh" "$CONFIG" --identity "$IDENTITY"

# ---------- 4. notarize .app ----------
notarize() {
    local target="$1"
    local zip
    zip="$(mktemp -d)/$(basename "$target").zip"

    step "Notarize: $target"
    ditto -c -k --keepParent "$target" "$zip"

    case "$NOTARY_MODE" in
        profile)
            xcrun notarytool submit "$zip" \
                --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
                --wait
            ;;
        creds)
            xcrun notarytool submit "$zip" \
                --apple-id "$APPLE_ID" \
                --password "$APPLE_APP_PASSWORD" \
                --team-id "$APPLE_TEAM_ID" \
                --wait
            ;;
        *)
            warn "skipping notarytool submit for $target"
            return 0 ;;
    esac

    step "Staple: $target"
    xcrun stapler staple "$target"
    xcrun stapler validate "$target"
}

if [[ "$NOTARY_MODE" != "none" ]]; then
    notarize "$APP_DIR"
fi

# ---------- 5. build DMG ----------
step "Build DMG"
mkdir -p "$DIST_DIR"
DMG_NAME="${APP_NAME}-${VERSION_VALUE}-${ARCH}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
rm -f "$DMG_PATH"

STAGE_DIR="$(mktemp -d)/dmg-stage"
mkdir -p "$STAGE_DIR"
cp -R "$APP_DIR" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

VOL_NAME="${APP_NAME} ${VERSION_VALUE}"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGE_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null
rm -rf "$STAGE_DIR"
echo "dmg: $DMG_PATH"

# ---------- 6. codesign DMG ----------
step "Codesign DMG"
codesign --force --sign "$IDENTITY" --timestamp "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

# ---------- 7. notarize + staple DMG ----------
if [[ "$NOTARY_MODE" != "none" ]]; then
    step "Notarize DMG"
    case "$NOTARY_MODE" in
        profile)
            xcrun notarytool submit "$DMG_PATH" \
                --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
                --wait
            ;;
        creds)
            xcrun notarytool submit "$DMG_PATH" \
                --apple-id "$APPLE_ID" \
                --password "$APPLE_APP_PASSWORD" \
                --team-id "$APPLE_TEAM_ID" \
                --wait
            ;;
    esac
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    spctl --assess --type open --context context:primary-signature -vv "$DMG_PATH" || \
        warn "spctl assess returned non-zero (sometimes expected on dmg)"
fi

step "Done"
echo "  app : $APP_DIR"
echo "  dmg : $DMG_PATH"
echo "  size: $(du -h "$DMG_PATH" | cut -f1)"
