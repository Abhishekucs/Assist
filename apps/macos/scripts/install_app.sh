#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT_DIR/scripts/lib/bundle_common.sh"

require_valid_configuration "scripts/install_app.sh"
resolve_bundle_configuration
select_sign_identity

DEFAULT_INSTALL_ROOT="/Applications"
if [[ -n "${ASSIST_INSTALL_ROOT:-}" ]]; then
  INSTALL_ROOT="$ASSIST_INSTALL_ROOT"
elif [[ -n "${AI_CLIPBOARD_INSTALL_ROOT:-}" ]]; then
  INSTALL_ROOT="$AI_CLIPBOARD_INSTALL_ROOT"
elif [[ -w "$DEFAULT_INSTALL_ROOT" ]]; then
  INSTALL_ROOT="$DEFAULT_INSTALL_ROOT"
else
  echo "error: /Applications is not writable. Set ASSIST_INSTALL_ROOT explicitly if you want another install path." >&2
  exit 1
fi
INSTALLED_PATH_FILE="$ROOT_DIR/.build/installed_app_path"

APP_DIR="$INSTALL_ROOT/$APP_BUNDLE_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

if [[ -d "$APP_DIR" ]]; then
  "$LSREGISTER" -u "$APP_DIR" >/dev/null 2>&1 || true
  rm -rf "$APP_DIR"
fi

assemble_app_bundle "$APP_DIR" "$ROOT_DIR/.build/$CONFIGURATION/$APP_NAME"
xattr -dr com.apple.quarantine "$APP_DIR" 2>/dev/null || true
sign_app_bundle "$APP_DIR"
"$LSREGISTER" -f "$APP_DIR" >/dev/null 2>&1 || true

mkdir -p "$(dirname "$INSTALLED_PATH_FILE")"
printf "%s\n" "$APP_DIR" > "$INSTALLED_PATH_FILE"
echo "Installed $APP_DIR"
