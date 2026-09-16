# Assist macOS design language

The two supplied Willow screenshots establish one shared language: a cool gray
navigation rail, a white inset content surface, charcoal text, restrained lavender
selection, and compact purple actions. The settings dialog repeats that language
with a simple navigation column, generous whitespace, and lightly outlined groups
separated by fine rules.

## Visual roles

| Role | Light appearance | Use |
| --- | --- | --- |
| Window / sidebar | `#F4F4F6` | Quiet outer frame and navigation |
| Content | `#FFFFFF` | Library, launch form, and settings |
| Primary text | `#3D3D42` | Titles, row labels, icons |
| Secondary text | `#66666D` | Descriptions and section labels |
| Accent | `#5142B8` | Primary actions and active controls |
| Accent surface | `#EEEBFA` | Keycaps and selected content |

These are reference-derived approximations, not a source design-token export.
Secondary text is darker than the sampled `#85858C` so captions keep at least
4.5:1 contrast on every light surface, including selection and lavender. Error
text uses `AssistTheme.dangerText` rather than the brighter destructive icon red.

Dark appearance preserves the hierarchy with charcoal surfaces and a lighter
lavender foreground. Window controllers apply the Light, Dark, or System
preference to the activation window, main window, and keyboard visualizer with
`NSWindow.followAppearance(of:)`; System leaves the window on the live macOS
appearance. `AssistAppSurface` builds the theme from the resulting color scheme.

## Type and layout

Use the native system sans serif, predominantly regular weight. Window headings
are 20–24 pt; settings headings are 17 pt; navigation and row labels are 13 pt;
supporting text is 11–12 pt. Keep text left aligned and use weight sparingly.

The main window has a 196 pt navigation rail and a flexible inset content pane.
The library keeps its screenshot/text grid and exposes the existing filters in
the rail. Shortcut guidance sits above history. Settings use a 196 pt navigation
column beside scrollable groups. Activation uses the same two-column hierarchy.

Controls use 7 pt radii, groups use 14 pt, and inset window/dialog surfaces use
18 pt. Rows inside a settings group share a 16 pt inset
(`AssistDesignTokens.Settings.rowInset`). Borders only delineate a settings
group, input action, or selection; focused text fields show an accent ring.
Chips and keycaps have no outline. Shadows are low contrast. Standalone icons
remain transparent until hover; actions that float over previews keep a card
backing. Destructive icons remain red.

Windows draw under a transparent title bar with no SwiftUI safe area, so each
window is exactly its view's frame (or, for the main window, its minimum frame).
Window backgrounds use the opaque `NSColor.assistWindowSurface`.

## Shared components

- `AssistDesignTokens` and `AssistTheme`: palette, typography, spacing, radii.
- `AssistAppSurface`: theme, type, and tint for a window's SwiftUI content.
- `NSWindow.followAppearance(of:)`: applies the persisted appearance preference.
- `AssistButtonStyle`, `assistTextField()`, `AssistKeycap`, `AssistNavigationRow`:
  common controls.
- `SettingsSection`, `SettingToggleRow`, `SettingsDialog`: grouped settings.
- `LibrarySidebar` and `LibraryWelcomeHeader`: library chrome and guidance.

The notch retains its black silhouette to meet the display edge. Its selected
filters, the editor's selected tools and chips, and primary actions use the same
purple accent family; selections on those dark surfaces use
`AssistDesignTokens.DarkSelection`.
Capture geometry, keyboard layouts, and image-editing behavior are unchanged.

All product icons reuse the existing bundled Hugeicons Stroke Rounded assets.
No new icon sources or licenses are introduced; see
`apps/macos/Sources/Assist/Resources/ThirdPartyNotices.md`.
