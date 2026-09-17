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
| Card | `#F8F8FA` | Settings groups and history cards on the content surface |
| Separator | `#E0E0E5` | Hairlines around groups and cards, and between rows |
| Primary text | `#3D3D42` | Titles, row labels, icons |
| Secondary text | `#66666D` | Descriptions and section labels |
| Accent | `#5142B8` | Primary actions and active controls |
| Dark primary action | `#B6A9FF` with `#17122E` label | Primary actions on dark surfaces |
| Accent surface | `#EEEBFA` | Keycaps and selected content |
| Control outline | `#84848C` | Text fields, secondary buttons, option tiles |

These are reference-derived approximations, not a source design-token export.
Secondary text is darker than the sampled `#85858C` so captions keep at least
4.5:1 contrast on every light surface, including selection and lavender. Error
text uses `AssistTheme.dangerText` rather than the brighter destructive icon red.
Control outlines keep at least 3:1 against every surface they sit on (`#807F88`
in dark appearance), so inputs and buttons read as controls. The `#5142B8`
primary fill is under 3:1 on dark surfaces, so dark appearance, the island, and
the editor use the lighter `#B6A9FF` fill with a dark label instead; controls
inside a primary button, such as its progress spinner, render for that fill.

Dark appearance preserves the hierarchy with charcoal surfaces and a lighter
lavender foreground. Window controllers apply the Light, Dark, or System
preference to the activation window, main window, and keyboard visualizer with
`NSWindow.followAppearance(of:)`; System leaves the window on the live macOS
appearance. `AssistAppSurface` builds the theme from the resulting color scheme.

## Type and layout

Use the native system sans serif, predominantly regular weight, through
`AssistDesignTokens.Typography`: window headings are 24 pt (`largeTitle`) and the
wordmark 20 pt
(`title`); settings and empty-state headings are 17 pt (`pageTitle`); list
headings are 15 pt (`sectionTitle`); navigation, row, and tile labels are 13 pt
(`label`); group labels are 12 pt (`section`); supporting text uses `caption`.
Keep text left aligned and use weight sparingly. Rows in a settings group are
leading-aligned; a preview that should be centered says so with its own frame.

The main window has a 196 pt navigation rail (`AssistDesignTokens.AppLayout`)
with the wordmark on top, beside a content surface inset 8 pt from the window
edge. The library keeps its screenshot/text grid and exposes the existing
filters in the rail. Shortcut guidance sits above history. Settings use a 196 pt
navigation column beside a page whose header stays fixed, clear of the dialog's
close button, while its groups scroll beneath it.

Activation is a single focused form on the content surface, with no rail: the
welcome heading, a line about the purchase receipt, the license key field with
any error below it, and Quit and Activate Assist at the bottom. The window is
480 × 340 pt and grows taller only when an error message needs the room.

Radii come from `AssistDesignTokens.Radius`: keycaps 6 pt, controls 7 pt, icon
buttons 8 pt, cards 10 pt, groups 14 pt, and inset window/dialog surfaces 18 pt.
Rows inside a settings group share a 16 pt inset
(`AssistDesignTokens.Settings.rowInset`).

Borders delineate settings groups and history cards (a hairline), and text
fields, secondary buttons, and option tiles (the control outline). Focused text
fields show an accent ring, and the whole field box accepts clicks. Selection
never relies on color alone: selected tiles add a check mark, selected cards a
heavier accent stroke with an inner ring (visible even on an accent-colored
clip), and selected navigation rows a medium weight and accent icon.
Navigation rows and icon buttons show hover and selection as foreground tints
(`AssistTheme.hoverFill` at 6% and `selectedFill` at 11%), so both read on the
sidebar and on the settings dialog, and a hovered row stays lighter than a
selected one. Chips and keycaps have no outline. Shadows are low contrast. Standalone
icons remain transparent until hover, and disabled controls are dimmed once, by
their button style or by AppKit; actions that float over previews keep a card
backing. Destructive icons remain red.

Windows draw under a transparent title bar with no SwiftUI safe area, so each
window is exactly its view's frame (or, for the main window, its minimum frame).
Window controllers pass the real title bar height to SwiftUI as
`EnvironmentValues.titleBarInset` through `WindowTitleBarMetrics`, which follows
changes such as full screen or a toolbar, and views pad their top content by it
rather than by a fixed number. Window backgrounds match the surface they host:
`NSColor.assistWindowSurface` for the library frame and
`NSColor.assistContentSurface` for activation.

## Shared components

- `AssistDesignTokens` and `AssistTheme`: palette, typography, spacing, radii.
- `AssistAppSurface`: theme, type, and tint for a window's SwiftUI content.
- `NSWindow.applyAssistChrome(background:appearanceFrom:)`: the shared title bar,
  background, and appearance setup for Assist windows.
- `AssistButtonStyle`, `assistTextField()`, `AssistKeycap`, `AssistNavigationRow`:
  common controls.
- `HugeIcon`: bundled icons; without an explicit color they take the
  surrounding foreground style.
- `SettingsDetailPage`, `SettingsSection`, `SettingsRow` (with
  `SettingToggleRow` and `SettingsValueText`), `SettingsControlGroup`,
  `SettingsDialog`: grouped settings. Every row with a title and a trailing
  control or value is a `SettingsRow`. The dialog paints the only settings
  background and is modal for VoiceOver.
- `LibrarySidebar` and `LibraryWelcomeHeader`: library chrome and guidance. The
  header carries the capture shortcuts, so empty states don't repeat them.
- `ClipboardHistoryFilter` presentation (`navigationTitle`, `icon`,
  `emptyTitle`): one source for the library and the island.

The notch retains its black silhouette to meet the display edge. Its selected
filters, the editor's selected tools and chips, and primary actions use the same
purple accent family through `AssistDesignTokens.DarkSurface`.
Capture geometry, keyboard layouts, and image-editing behavior are unchanged.

All product icons reuse the existing bundled Hugeicons Stroke Rounded assets.
No new icon sources or licenses are introduced; see
`apps/macos/Sources/Assist/Resources/ThirdPartyNotices.md`.
