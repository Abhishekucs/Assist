# Assist

Assist is a native macOS screenshot utility for quick annotation and structured context capture.

The first version is intentionally small:

- Hold `Option` anywhere on macOS to start an annotated capture.
- Move the pointer while holding `Option` to annotate.
- Release `Option` to save the annotated screenshot.
- Press `Control + Option` to save a clean full-display screenshot without annotation.
- Hover the top-center pill to preview the latest capture.
- Copy the screenshot or local structured context from the pill.
- Screenshot metadata is stored in a local SQLite database.
- Vision OCR runs locally to create the first-pass context.
- Built-in diagnostic actions help isolate overlay and capture issues.

## Why Native Swift

This app depends on macOS-level behavior: global modifier-key tracking, transparent always-on-top panels, screen capture, and smooth pill-style animation. The project uses SwiftUI for user-facing UI, AppKit for windows and input, and ScreenCaptureKit as the primary capture engine.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer, or a Swift toolchain that supports Swift 6

## Build

```sh
cd apps/macos
make build
```

The app bundle is created at:

```text
.build/Assist Dev.app
```

Run it with:

```sh
make run
```

`make run` installs and opens a stable development copy at:

```text
/Applications/Assist Dev.app
```

Development and production are separate apps that can coexist:

| | Debug | Release |
| --- | --- | --- |
| App name | Assist Dev | Assist |
| Bundle ID | `com.thinkingsoundlab.assist.dev` | `com.thinkingsoundlab.assist` |
| Install path | `/Applications/Assist Dev.app` | `/Applications/Assist.app` |
| Support dir | `~/Library/Application Support/Assist Dev` | `~/Library/Application Support/Assist` |
| Hardened runtime | off (lldb can attach) | on |

macOS TCC keys permission grants to the bundle ID plus the code-signing
requirement, so each flavor needs its own bundle ID and a signature that stays
stable across rebuilds. Grant Screen Recording and Accessibility to
`/Applications/Assist Dev.app` once and the grants survive rebuilds.

Debug builds are signed with your Apple Development certificate when one is in
the keychain (add one via Xcode > Settings > Accounts). Without one, the
self-signed `Assist Local Development` identity is used; create it with:

```sh
scripts/create_dev_certificate.sh
make run
```

Debug builds refuse to fall back to ad-hoc signing, because an ad-hoc
signature changes on every rebuild and resets the TCC permission grants.

If a permission prompt loops or the app does not appear in System Settings,
a stale TCC row from an earlier signature is usually the cause. Reset with:

```sh
tccutil reset ScreenCapture com.thinkingsoundlab.assist.dev
tccutil reset Accessibility com.thinkingsoundlab.assist.dev
tccutil reset ListenEvent com.thinkingsoundlab.assist.dev
```

Create a local release DMG with:

```sh
make release
```

When `ASSIST_SIGN_IDENTITY`, `ASSIST_REQUIRE_SIGNING=1`, and
`ASSIST_HARDENED_RUNTIME=1` are set, the release DMG is Developer ID signed
and ready for notarization.

## GitHub Releases

The GitHub Actions release workflow runs for macOS release tags that start with
`macos-v`, such as `macos-v0.1.0`. Plain `v*` tags do not trigger the macOS
release workflow.

For tag-triggered runs, the workflow first compares the new tag commit with the
previous `macos-v*` tag, falling back to the latest legacy `v*` tag during the
tag-prefix migration. It builds a release DMG, signs the app with the Developer
ID Application certificate, notarizes the DMG with Apple, staples the ticket,
verifies Gatekeeper acceptance, and uploads both versioned and stable DMG
assets only when macOS release inputs changed:

```text
apps/macos/**
.github/workflows/release.yml
```

Manual workflow dispatches are treated as explicit release requests and always
run the build, signing, notarization, verification, and release steps.

The workflow is pinned to:

```text
Team ID: 4M5LV534N5
Signing identity: Developer ID Application: THINKING SOUND LAB PRIVATE LIMITED (4M5LV534N5)
```

Configure these GitHub Actions secrets before creating a release tag:

```text
APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64
APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
APPLE_KEYCHAIN_PASSWORD
APPLE_ID
APPLE_APP_SPECIFIC_PASSWORD
```

To prepare the certificate secret, open Keychain Access and export only this
item as a `.p12`:

```text
Developer ID Application: THINKING SOUND LAB PRIVATE LIMITED (4M5LV534N5)
```

Then generate a fresh app-specific password from the company Apple Account for
GitHub Actions and run:

```sh
apps/macos/scripts/configure_github_release_secrets.sh /path/to/developer-id-application.p12
```

To publish a release:

```sh
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.1.2" apps/macos/Sources/AIClipboard/Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 3" apps/macos/Sources/AIClipboard/Resources/Info.plist
git commit -am "Bump macOS app to 0.1.2"
git tag macos-v0.1.2
git push origin HEAD macos-v0.1.2
```

## Permissions

Assist asks for:

- Screen Recording, to capture the screen.
- Accessibility/Input Monitoring, to detect the global `Option` and `Control + Option` shortcuts.

If capture or the global gesture does not work after granting permissions, quit and reopen the app.

The app does not block behind a permission gateway. Capture is attempted directly, and failures are reported through status text plus the debug log.

## License Activation

Debug builds open without activation. Release builds show an activation window
before the app creates its menu bar item, capture monitors, pill, or control
panel. A successful activation is validated by the web app's
`/api/license/verify` route and stored in the macOS Keychain.

The activation endpoint is configured in `Info.plist` with
`AssistLicenseVerificationURL`.

The expanded pill includes diagnostic buttons:

- `Test Overlay` draws a temporary annotation path without using screen capture.
- `Test Screenshot` captures and stores a clean screenshot under the pointer.
- `Log` opens the local debug log.

The debug log is written to:

```text
~/Library/Application Support/Assist/debug.log
```

## Architecture

```text
Sources/AIClipboard
├── AppDelegate.swift
├── Core
│   ├── AppCoordinator.swift
│   └── Models.swift
├── Services
│   ├── CaptureService.swift
│   ├── CaptureStore.swift
│   ├── ControlGestureMonitor.swift
│   ├── DebugLogger.swift
│   ├── VisionAnalysisService.swift
│   └── WindowManager.swift
└── Views
    ├── AnnotationOverlayView.swift
    ├── PillView.swift
    └── PillViewModel.swift
```

The main flow is:

```text
Option down
→ show transparent annotation overlay
→ record pointer path
→ Option up
→ hide overlay and capture the active display
→ composite annotation onto screenshot
→ save PNG and thumbnail
→ run local Vision OCR
→ update pill preview
```

Capture implementation:

```text
ScreenCaptureKit display capture
→ exact error/status reporting in the pill
→ diagnostic capture paths only when explicitly compiled for diagnostics
```

Captures are stored in:

```text
~/Library/Application Support/Assist/
├── captures.sqlite
└── Captures/
    ├── <capture-id>.png
    └── <capture-id>-thumb.png
```

The database stores capture metadata, paths, timestamps, and structured context. PNG files stay on disk so the database remains small and easy to inspect.

## Current Limitations

- The first version captures the display under the pointer, not a stitched multi-display canvas.
- Context generation is local Vision OCR, not a remote multimodal model yet.
- The annotation gesture uses `Option` directly; future versions should add a setting to customize shortcuts.

## Roadmap

- Configurable trigger key.
- Region redaction and blur tools.
- Screenshot history search.
- JSON and Markdown agent export formats.
- Optional remote vision model integration.
- MCP/local API for agent handoff.
