# Agent Rules

These rules apply to this repository. Follow them when adding or changing code.

## UI And Iconography

- Always use Hugeicons for app UI icons when an icon exists in the Hugeicons free set.
- Do not create custom-drawn icons with SwiftUI `Canvas`, manual `Path`, ad hoc SVG code, or hand-rolled vector geometry for product UI.
- Use official Hugeicons sources only: the Hugeicons Swift package when available for the needed icon/style, or downloaded Hugeicons free SVG/PDF assets stored in the app resources or asset catalog.
- Keep icons visually consistent: prefer the Hugeicons Stroke Rounded style, 24px grid proportions, and a single stroke weight per surface.
- Do not mix SF Symbols into primary product UI unless there is no suitable Hugeicons alternative or the control is a native macOS system affordance.
- Add tooltips or accessibility labels for icon-only buttons.
- Do not put persistent background fills behind standalone icons or icon-only buttons. Keep icon backgrounds transparent by default and use a subtle hover-state color only when the icon is interactive.
- For destructive icon-only actions such as delete, use a red line icon with a light red hover-state background so the action is clearly destructive.

## Icon Asset Pipeline

- Prefer a real asset pipeline over custom drawing:
  - Put reusable icon assets in `apps/macos/Sources/AIClipboard/Resources/Icons/` or an asset catalog when the project moves to an Xcode project layout.
  - Add a small SwiftUI wrapper that renders bundled icon assets by name, applies size/color consistently, and exposes accessibility labels.
  - Keep icon names mapped in one place so views never guess raw file names.
- Follow the pattern used by mature macOS apps: bundled assets for custom brand/product icons, native system affordances only where the platform expects them.
- If adding or changing icons, document the source and license of the icon set in the repository.

## Visual Design

- Respect Apple platform conventions: restrained surfaces, clear hierarchy, compact controls, and native-feeling motion.
- Do not add unnecessary borders. Use borders only when they clarify grouping, focus, selection, or separation.
- Prefer spacing, background contrast, and typography before adding outlines.
- Keep corner radii modest for app windows, dialogs, cards, and controls. Avoid overly rounded shapes unless matching the notch/island surface.
- Avoid decorative gradients, heavy shadows, and visual noise unless they serve a clear interaction state.

## File Structure

- Keep files organized by responsibility:
  - `Core/` for models, identity, settings, and coordination primitives.
  - `Services/` for persistence, capture, permissions, windows, and system integrations.
  - `Views/` for SwiftUI/AppKit UI surfaces and view models.
  - `Resources/` for fonts, app metadata, and bundled static assets.
  - `scripts/` for build, install, release, and automation scripts.
- Do not place service logic inside SwiftUI views. Move side effects into services or view models.
- Do not place reusable UI primitives inside large feature views when they are used by multiple surfaces. Extract them into a focused view file.
- Keep feature changes scoped. Avoid broad refactors unless required for the requested behavior.

## Implementation Quality

- Prefer native Swift and AppKit/SwiftUI APIs over custom workarounds.
- Do not implement fallback code paths as the fix for a bug. Fallbacks should not
  mask unresolved state, lifecycle, payment, licensing, permission, or data-flow
  problems.
- Do not use `setTimeout`, artificial sleeps, delayed retries, or timing-based
  workarounds to paper over race conditions or missing state. Trace the actual
  event, data, and ownership flow, then fix the source of the problem.
- Before changing code, inspect the relevant codebase path and identify the
  robust owner of the behavior. Prefer a durable root-cause fix over a local
  patch, shim, or workaround.
- Do not patch over symptoms. If a proposed change only hides the problem,
  keep investigating until the real cause and best solution are clear.
- Preserve existing user data and permissions behavior.
- Build after code changes with `swift build`.
- When changing launch, build, packaging, or resources, also verify `make run` or the relevant script path.
