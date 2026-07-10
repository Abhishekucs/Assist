#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: scripts/configure_github_release_secrets.sh /path/to/developer-id-application.p12

Exports the selected .p12 into GitHub Actions secrets for the macOS release workflow.
Create the .p12 first from Keychain Access by exporting only:
Developer ID Application: THINKING SOUND LAB PRIVATE LIMITED (4M5LV534N5)
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

P12_PATH="${1:-}"
if [[ -z "$P12_PATH" || ! -f "$P12_PATH" ]]; then
  usage
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: GitHub CLI is required. Install gh and run gh auth login first." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "error: GitHub CLI is not authenticated. Run gh auth login first." >&2
  exit 1
fi

DEFAULT_APPLE_ID="abhishek@thinkingsoundlab.com"

read -r -p "Apple ID [$DEFAULT_APPLE_ID]: " APPLE_ID
APPLE_ID="${APPLE_ID:-$DEFAULT_APPLE_ID}"

read -r -s -p "Password used when exporting the .p12: " CERTIFICATE_PASSWORD
printf "\n"

read -r -s -p "Apple app-specific password for $APPLE_ID: " APP_SPECIFIC_PASSWORD
printf "\n"

KEYCHAIN_PASSWORD="$(openssl rand -base64 32 | tr -d '\n')"
CERTIFICATE_BASE64="$(base64 < "$P12_PATH" | tr -d '\n')"

printf "%s" "$CERTIFICATE_BASE64" | gh secret set APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64
printf "%s" "$CERTIFICATE_PASSWORD" | gh secret set APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
printf "%s" "$KEYCHAIN_PASSWORD" | gh secret set APPLE_KEYCHAIN_PASSWORD
printf "%s" "$APPLE_ID" | gh secret set APPLE_ID
printf "%s" "$APP_SPECIFIC_PASSWORD" | gh secret set APPLE_APP_SPECIFIC_PASSWORD

echo "GitHub Actions release secrets have been configured."
