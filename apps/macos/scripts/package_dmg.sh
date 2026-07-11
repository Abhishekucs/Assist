#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-release}"
APP_NAME="Assist"
REQUIRE_SIGNING="${ASSIST_REQUIRE_SIGNING:-0}"
TIMESTAMP="${ASSIST_TIMESTAMP:-0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/Sources/Assist/Resources/Info.plist"
VERSION="${2:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")}"
BUILD_DIR="$ROOT_DIR/.build"
if [[ "$CONFIGURATION" == "debug" ]]; then
  APP_BUNDLE_NAME="Assist Dev"
else
  APP_BUNDLE_NAME="Assist"
fi
APP_DIR="$BUILD_DIR/$APP_BUNDLE_NAME.app"
DIST_DIR="$BUILD_DIR/dist"
STAGING_DIR="$BUILD_DIR/dmg-staging"
MOUNT_DIR="$BUILD_DIR/dmg-mount"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
RW_DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-rw.dmg"
VOLUME_NAME="$APP_NAME $VERSION"
BACKGROUND_PATH="$STAGING_DIR/.background/background.png"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Usage: scripts/package_dmg.sh [debug|release] [version]" >&2
    exit 1
    ;;
esac

"$ROOT_DIR/scripts/build_app.sh" "$CONFIGURATION"

rm -rf "$DIST_DIR" "$STAGING_DIR" "$MOUNT_DIR"
mkdir -p "$DIST_DIR" "$STAGING_DIR" "$MOUNT_DIR"

ditto "$APP_DIR" "$STAGING_DIR/$APP_BUNDLE_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$STAGING_DIR/.fseventsd"
touch "$STAGING_DIR/.fseventsd/no_log"
"$ROOT_DIR/scripts/create_dmg_background.swift" "$BACKGROUND_PATH"
sync

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$RW_DMG_PATH"

attached=0
cleanup_mount() {
  if [[ "$attached" == "1" ]]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || hdiutil detach -force "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
}
trap cleanup_mount EXIT

hdiutil attach "$RW_DMG_PATH" -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" >/dev/null
attached=1

osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$MOUNT_DIR" as alias
  open dmgFolder
  delay 1

  set containerWindow to container window of dmgFolder
  set current view of containerWindow to icon view
  set toolbar visible of containerWindow to false
  set statusbar visible of containerWindow to false
  set bounds of containerWindow to {120, 120, 840, 580}

  set viewOptions to icon view options of containerWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 128
  set background picture of viewOptions to file ".background:background.png" of dmgFolder

  set position of item "$APP_BUNDLE_NAME.app" of dmgFolder to {220, 252}
  set position of item "Applications" of dmgFolder to {500, 252}

  update dmgFolder without registering applications
  delay 1
  close containerWindow
end tell
APPLESCRIPT

sync
if [[ ! -f "$MOUNT_DIR/.DS_Store" ]]; then
  echo "error: Finder did not persist the DMG window layout metadata" >&2
  exit 1
fi
hdiutil detach "$MOUNT_DIR" >/dev/null
attached=0
trap - EXIT

hdiutil convert "$RW_DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" \
  >/dev/null
rm -f "$RW_DMG_PATH"

if [[ -n "${ASSIST_SIGN_IDENTITY:-}" ]] && security find-identity -v -p codesigning | grep -F "\"$ASSIST_SIGN_IDENTITY\"" >/dev/null; then
  CODESIGN_ARGS=(--force --sign "$ASSIST_SIGN_IDENTITY")
  if [[ "$TIMESTAMP" == "1" ]]; then
    CODESIGN_ARGS+=(--timestamp)
  fi
  codesign "${CODESIGN_ARGS[@]}" "$DMG_PATH"
elif [[ "$REQUIRE_SIGNING" == "1" ]]; then
  echo "error: signing identity '${ASSIST_SIGN_IDENTITY:-}' not found for DMG signing" >&2
  exit 1
fi

printf "%s\n" "$DMG_PATH" > "$BUILD_DIR/dmg_path"
echo "Packaged $DMG_PATH"
