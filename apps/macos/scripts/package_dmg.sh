#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-release}"
APP_NAME="Assist"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/Sources/AIClipboard/Resources/Info.plist"
VERSION="${2:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")}"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DIST_DIR="$BUILD_DIR/dist"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
VOLUME_NAME="$APP_NAME $VERSION"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Usage: scripts/package_dmg.sh [debug|release] [version]" >&2
    exit 1
    ;;
esac

"$ROOT_DIR/scripts/build_app.sh" "$CONFIGURATION"

rm -rf "$DIST_DIR" "$STAGING_DIR"
mkdir -p "$DIST_DIR" "$STAGING_DIR"

ditto "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
sync

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "${ASSIST_SIGN_IDENTITY:-}" ]] && security find-identity -v -p codesigning | grep -F "\"$ASSIST_SIGN_IDENTITY\"" >/dev/null; then
  codesign --force --sign "$ASSIST_SIGN_IDENTITY" "$DMG_PATH"
fi

printf "%s\n" "$DMG_PATH" > "$BUILD_DIR/dmg_path"
echo "Packaged $DMG_PATH"
