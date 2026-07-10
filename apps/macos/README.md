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
.build/Assist.app
```

Run it with:

```sh
make run
```

`make run` installs and opens a stable development copy at:

```text
/Applications/Assist.app
```

Use the `/Applications` app when granting Screen Recording permission. Avoid granting permission to `.build/Assist.app`; that bundle is disposable and may be recreated during development.

For local development, use a stable signing identity so macOS Screen Recording permission survives rebuilds:

```sh
scripts/create_dev_certificate.sh
make run
```

Create a local release DMG with:

```sh
make release
```

When `ASSIST_SIGN_IDENTITY`, `ASSIST_REQUIRE_SIGNING=1`, and
`ASSIST_HARDENED_RUNTIME=1` are set, the release DMG is Developer ID signed
and ready for notarization.

## GitHub Releases

The GitHub Actions release workflow runs for tags that start with `v`, such as
`v0.1.0`. It builds a release DMG, signs the app with the Developer ID
Application certificate, notarizes the DMG with Apple, staples the ticket,
verifies Gatekeeper acceptance, and uploads both versioned and stable DMG
assets to the GitHub Release.

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
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.1.1" apps/macos/Sources/AIClipboard/Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 2" apps/macos/Sources/AIClipboard/Resources/Info.plist
git commit -am "Bump macOS app to 0.1.1"
git tag v0.1.1
git push origin HEAD v0.1.1
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
