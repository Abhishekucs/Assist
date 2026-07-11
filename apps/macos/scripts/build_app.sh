#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"

source "$ROOT_DIR/scripts/lib/bundle_common.sh"

require_valid_configuration "scripts/build_app.sh"
resolve_bundle_configuration
select_sign_identity

APP_DIR="$BUILD_DIR/$APP_BUNDLE_NAME.app"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
assemble_app_bundle "$APP_DIR" "$BUILD_DIR/$CONFIGURATION/$APP_NAME"
sign_app_bundle "$APP_DIR"

echo "Built $APP_DIR"
