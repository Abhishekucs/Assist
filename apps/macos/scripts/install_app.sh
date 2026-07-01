#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
APP_NAME="AIClipboard"
DEV_SIGN_IDENTITY="${AI_CLIPBOARD_SIGN_IDENTITY:-AI Clipboard Local Development}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_INSTALL_ROOT="/Applications"
if [[ -n "${AI_CLIPBOARD_INSTALL_ROOT:-}" ]]; then
  INSTALL_ROOT="$AI_CLIPBOARD_INSTALL_ROOT"
elif [[ -w "$DEFAULT_INSTALL_ROOT" ]]; then
  INSTALL_ROOT="$DEFAULT_INSTALL_ROOT"
else
  echo "error: /Applications is not writable. Set AI_CLIPBOARD_INSTALL_ROOT explicitly if you want another install path." >&2
  exit 1
fi
APP_DIR="$INSTALL_ROOT/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INSTALLED_PATH_FILE="$ROOT_DIR/.build/installed_app_path"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Usage: scripts/install_app.sh [debug|release]" >&2
    exit 1
    ;;
esac

swift build -c "$CONFIGURATION"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/$CONFIGURATION/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Sources/AIClipboard/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/$APP_NAME"
xattr -dr com.apple.quarantine "$APP_DIR" 2>/dev/null || true

if security find-identity -v -p codesigning | grep -F "\"$DEV_SIGN_IDENTITY\"" >/dev/null; then
  codesign --force --deep --sign "$DEV_SIGN_IDENTITY" "$APP_DIR"
else
  echo "warning: signing identity '$DEV_SIGN_IDENTITY' not found; falling back to ad-hoc signing" >&2
  codesign --force --deep --sign - "$APP_DIR"
fi

mkdir -p "$(dirname "$INSTALLED_PATH_FILE")"
printf "%s\n" "$APP_DIR" > "$INSTALLED_PATH_FILE"
echo "Installed $APP_DIR"
