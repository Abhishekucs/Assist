# Shared configuration for build_app.sh / install_app.sh.
# Expects CONFIGURATION and ROOT_DIR to be set before sourcing.

APP_NAME="Assist"
REQUIRE_SIGNING="${ASSIST_REQUIRE_SIGNING:-0}"
TIMESTAMP="${ASSIST_TIMESTAMP:-0}"
DEVELOPER_ID_SIGN_IDENTITY="Developer ID Application: THINKING SOUND LAB PRIVATE LIMITED (4M5LV534N5)"
LOCAL_SIGN_IDENTITY="Assist Local Development"

has_signing_identity() {
  security find-identity -v -p codesigning | grep -F "\"$1\"" >/dev/null
}

first_apple_development_identity() {
  security find-identity -v -p codesigning | awk -F '"' '/"Apple Development:/{print $2; exit}'
}

plist_set_or_add_string() {
  local key="$1"
  local value="$2"
  local plist="$3"
  /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist"
}

require_valid_configuration() {
  case "$CONFIGURATION" in
    debug|release) ;;
    *)
      echo "Usage: $1 [debug|release]" >&2
      exit 1
      ;;
  esac
}

# Debug and release are separate apps: distinct bundle IDs, names, and install
# paths, so each keeps its own TCC permission grants and both can coexist.
resolve_bundle_configuration() {
  if [[ "$CONFIGURATION" == "release" ]]; then
    APP_BUNDLE_NAME="Assist"
    BUNDLE_IDENTIFIER="com.thinkingsoundlab.assist"
    LSUIELEMENT="true"
    DEVELOPMENT_BUILD="false"
    ENTITLEMENTS_FILE="$ROOT_DIR/Assist.entitlements"
    HARDENED_RUNTIME="${ASSIST_HARDENED_RUNTIME:-1}"
  else
    APP_BUNDLE_NAME="Assist Dev"
    BUNDLE_IDENTIFIER="com.thinkingsoundlab.assist.dev"
    LSUIELEMENT="false"
    DEVELOPMENT_BUILD="true"
    ENTITLEMENTS_FILE="$ROOT_DIR/Assist-dev.entitlements"
    HARDENED_RUNTIME="${ASSIST_HARDENED_RUNTIME:-0}"
  fi
}

# TCC keys permission grants to (bundle ID + code-signing requirement), so the
# signature must stay stable across rebuilds. Debug prefers an Apple-chained
# Apple Development identity (its designated requirement is team-based and
# survives certificate renewal), then the self-signed local identity.
select_sign_identity() {
  local apple_development_identity
  apple_development_identity="$(first_apple_development_identity)"

  if [[ -n "${ASSIST_SIGN_IDENTITY:-}" ]]; then
    SIGN_IDENTITY="$ASSIST_SIGN_IDENTITY"
  elif [[ "$CONFIGURATION" == "debug" ]]; then
    if [[ -n "$apple_development_identity" ]]; then
      SIGN_IDENTITY="$apple_development_identity"
    elif has_signing_identity "$LOCAL_SIGN_IDENTITY"; then
      SIGN_IDENTITY="$LOCAL_SIGN_IDENTITY"
    else
      SIGN_IDENTITY=""
    fi
  elif has_signing_identity "$DEVELOPER_ID_SIGN_IDENTITY"; then
    SIGN_IDENTITY="$DEVELOPER_ID_SIGN_IDENTITY"
  elif [[ -n "$apple_development_identity" ]]; then
    SIGN_IDENTITY="$apple_development_identity"
  else
    SIGN_IDENTITY=""
  fi
}

stamp_info_plist() {
  local plist="$1"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_BUNDLE_NAME" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_BUNDLE_NAME" "$plist"
  /usr/libexec/PlistBuddy -c "Set :LSUIElement $LSUIELEMENT" "$plist"
  /usr/libexec/PlistBuddy -c "Set :AssistDevelopmentBuild $DEVELOPMENT_BUILD" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleSupportedPlatforms:0 MacOSX" "$plist" >/dev/null 2>&1 || {
    /usr/libexec/PlistBuddy -c "Delete :CFBundleSupportedPlatforms" "$plist" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleSupportedPlatforms array" "$plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleSupportedPlatforms:0 string MacOSX" "$plist"
  }
  plist_set_or_add_string "DTPlatformName" "macosx" "$plist"
  plist_set_or_add_string "DTSDKName" "macosx$(xcrun --sdk macosx --show-sdk-version)" "$plist"
  plist_set_or_add_string "DTXcode" "$(xcodebuild -version | awk '/Xcode/{gsub(/\./, "", $2); print $2; exit}')" "$plist"
}

assemble_app_bundle() {
  local app_dir="$1"
  local binary_path="$2"
  local contents_dir="$app_dir/Contents"
  local macos_dir="$contents_dir/MacOS"
  local resources_dir="$contents_dir/Resources"

  mkdir -p "$macos_dir" "$resources_dir"
  cp "$binary_path" "$macos_dir/$APP_NAME"
  cp "$ROOT_DIR/Sources/Assist/Resources/Info.plist" "$contents_dir/Info.plist"
  stamp_info_plist "$contents_dir/Info.plist"
  rsync -a --exclude "Info.plist" "$ROOT_DIR/Sources/Assist/Resources/" "$resources_dir/"
  printf "APPL????" > "$contents_dir/PkgInfo"
  chmod +x "$macos_dir/$APP_NAME"
}

sign_app_bundle() {
  local app_dir="$1"

  if [[ -n "$SIGN_IDENTITY" ]] && has_signing_identity "$SIGN_IDENTITY"; then
    local codesign_args=(--force --deep --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_FILE")
    if [[ "$HARDENED_RUNTIME" == "1" ]]; then
      codesign_args+=(--options runtime)
    fi
    if [[ "$TIMESTAMP" == "1" ]]; then
      codesign_args+=(--timestamp)
    fi
    echo "Signing $app_dir with $SIGN_IDENTITY"
    codesign "${codesign_args[@]}" "$app_dir"
    return 0
  fi

  # Ad-hoc signatures pin the binary hash, so every rebuild becomes a new TCC
  # identity and permissions reset. Debug builds refuse to fall back.
  if [[ "$CONFIGURATION" == "debug" ]]; then
    echo "error: no stable code-signing identity found for the debug build." >&2
    echo "Screen Recording and input permissions only survive rebuilds with a stable signature." >&2
    echo "Either add an Apple Development certificate (Xcode > Settings > Accounts) or run:" >&2
    echo "  scripts/create_dev_certificate.sh" >&2
    exit 1
  fi

  if [[ "$REQUIRE_SIGNING" == "1" ]]; then
    echo "error: signing identity '$SIGN_IDENTITY' not found" >&2
    exit 1
  fi

  echo "warning: no signing identity found; falling back to ad-hoc signing (TCC permissions will reset on each rebuild)" >&2
  codesign --force --deep --sign - --entitlements "$ENTITLEMENTS_FILE" "$app_dir"
}
