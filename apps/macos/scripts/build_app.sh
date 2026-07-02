#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
APP_NAME="Assist"
DEV_SIGN_IDENTITY="${ASSIST_SIGN_IDENTITY:-${AI_CLIPBOARD_SIGN_IDENTITY:-Assist Local Development}}"
REQUIRE_SIGNING="${ASSIST_REQUIRE_SIGNING:-0}"
HARDENED_RUNTIME="${ASSIST_HARDENED_RUNTIME:-0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Usage: scripts/build_app.sh [debug|release]" >&2
    exit 1
    ;;
esac

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/$CONFIGURATION/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Sources/AIClipboard/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

chmod +x "$MACOS_DIR/$APP_NAME"

if security find-identity -v -p codesigning | grep -F "\"$DEV_SIGN_IDENTITY\"" >/dev/null; then
  CODESIGN_ARGS=(--force --deep --sign "$DEV_SIGN_IDENTITY")
  if [[ "$HARDENED_RUNTIME" == "1" ]]; then
    CODESIGN_ARGS+=(--options runtime)
  fi
  codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"
else
  if [[ "$REQUIRE_SIGNING" == "1" ]]; then
    echo "error: signing identity '$DEV_SIGN_IDENTITY' not found" >&2
    exit 1
  fi
  echo "warning: signing identity '$DEV_SIGN_IDENTITY' not found; falling back to ad-hoc signing" >&2
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "Built $APP_DIR"
