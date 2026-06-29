# Assist

Assist is a native macOS screenshot utility for quick annotation and structured context capture.

The first version is intentionally small:

- Hold `Control` anywhere on macOS to start a capture.
- Move the pointer while holding `Control` to annotate.
- Release `Control` to save the annotated screenshot.
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

## Permissions

Assist asks for:

- Screen Recording, to capture the screen.
- Accessibility/Input Monitoring, to detect the global `Control` hold gesture.

If capture or the global gesture does not work after granting permissions, quit and reopen the app.

The app does not block behind a permission gateway. Capture is attempted directly, and failures are reported through status text plus the debug log.

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
Control down
→ show transparent annotation overlay
→ record pointer path
→ Control up
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
- The `Control`-only gesture is intentionally direct; future versions should add a setting to choose a safer trigger.
- App signing and notarization are not configured yet.

## Roadmap

- Configurable trigger key.
- Region redaction and blur tools.
- Screenshot history search.
- JSON and Markdown agent export formats.
- Optional remote vision model integration.
- MCP/local API for agent handoff.
- Signed and notarized release pipeline.
