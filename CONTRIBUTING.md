# Contributing

Thanks for helping improve AI Clipboard.

## Development Principles

- Keep the capture path fast and predictable.
- Prefer native macOS APIs for global input, capture, panels, and permissions.
- Keep AI integrations behind services so local and remote analysis can coexist.
- Avoid storing secrets in app data.
- Treat screenshots as sensitive user data by default.

## Local Workflow

```sh
make build
make run
```

Before opening a pull request, run:

```sh
swift build
```

## Code Style

- Use Swift concurrency where it makes the flow clearer.
- Keep AppKit-specific behavior in services or window management types.
- Keep SwiftUI views mostly declarative and state-driven.
- Add comments only for non-obvious system behavior.
