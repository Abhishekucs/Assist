# Release Automation

Assist ships from GitHub Actions as a macOS DMG attached to a GitHub Release.
The same workflow also uploads a stable `Assist.dmg` asset so the website can
link to the latest installer without knowing the current version.

## Required GitHub Secrets

Unsigned DMGs can be built without Apple secrets, but public distribution should
use Developer ID signing and notarization.

- `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`: Base64 text for the
  Developer ID Application `.p12` certificate.
- `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`: Password used when
  exporting the `.p12`.
- `APPLE_DEVELOPER_ID_APPLICATION_IDENTITY`: Exact codesign identity, for
  example `Developer ID Application: Your Name (TEAMID)`.
- `APPLE_KEYCHAIN_PASSWORD`: Random CI-only password for the temporary keychain.
- `APPLE_ID`: Apple ID used for notarization.
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password for that Apple ID.
- `APPLE_TEAM_ID`: Apple developer team ID.

To copy the certificate into a GitHub secret:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

## Manual Local Build

```bash
apps/macos/scripts/package_dmg.sh release
```

The DMG is written to `apps/macos/.build/dist/Assist-<version>.dmg`.

## GitHub Release Flow

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in
   `apps/macos/Sources/AIClipboard/Resources/Info.plist`.
2. Commit and push the version bump.
3. Create and push a matching tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow creates or updates the GitHub Release for that tag and uploads:

- `Assist-<version>.dmg`
- `Assist.dmg`

For the website download button, use the stable release asset URL:

```text
https://github.com/Thinking-Sound-Lab/Assist/releases/latest/download/Assist.dmg
```
