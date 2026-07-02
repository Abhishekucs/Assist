#!/usr/bin/env bash
set -euo pipefail

CERT_NAME="${ASSIST_SIGN_IDENTITY:-${AI_CLIPBOARD_SIGN_IDENTITY:-Assist Local Development}}"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -F "\"$CERT_NAME\"" >/dev/null; then
  echo "Code-signing identity already exists: $CERT_NAME"
  exit 0
fi

TMPDIR_CERT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CERT"' EXIT

openssl req \
  -x509 \
  -newkey rsa:2048 \
  -keyout "$TMPDIR_CERT/assist.key" \
  -out "$TMPDIR_CERT/assist.crt" \
  -days 3650 \
  -nodes \
  -subj "/CN=$CERT_NAME/" \
  -addext "extendedKeyUsage=codeSigning" \
  -addext "keyUsage=digitalSignature" >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -inkey "$TMPDIR_CERT/assist.key" \
  -in "$TMPDIR_CERT/assist.crt" \
  -out "$TMPDIR_CERT/assist.p12" \
  -passout pass:assist >/dev/null 2>&1

security import "$TMPDIR_CERT/assist.p12" \
  -k "$KEYCHAIN" \
  -P "assist" \
  -T /usr/bin/codesign >/dev/null

security add-trusted-cert \
  -d \
  -r trustRoot \
  -p codeSign \
  -k "$KEYCHAIN" \
  "$TMPDIR_CERT/assist.crt" >/dev/null

security find-identity -v -p codesigning | grep -F "\"$CERT_NAME\""
