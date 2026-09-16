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
| Secondary text | `#85858C` | Descriptions and section labels |
| Accent | `#5142B8` | Primary actions and active controls |
| Accent surface | `#EEEBFA` | Keycaps and selected content |

These are reference-derived approximations, not a source design-token export.
Dark appearance preserves the hierarchy with charcoal surfaces and a lighter
lavender foreground. Existing Light, Dark, and System preferences apply to both
the activation window and main application through `AssistAppSurface`.

## Type and layout

Use the native system sans serif, predominantly regular weight. Window headings
are 20–24 pt; settings headings are 17 pt; navigation and row labels are 13 pt;
supporting text is 11–12 pt. Keep text left aligned and use weight sparingly.

The main window has a 196 pt navigation rail and a flexible inset content pane.
The library keeps its screenshot/text grid and exposes the existing filters in
the rail. Shortcut guidance sits above history. Settings use a 196 pt navigation
column beside scrollable groups. Activation uses the same two-column hierarchy.

Controls use 7 pt radii, groups use 14 pt, and inset window/dialog surfaces use
18 pt. Borders only delineate a settings group, input action, or selection. Chips
and keycaps have no outline. Shadows are low contrast. Standalone icons remain
transparent until hover; destructive icons remain red.

## Shared components

- `AssistDesignTokens` and `AssistTheme`: palette, typography, spacing, radii.
- `AssistAppSurface`: persisted and system appearance resolution for windows.
- `AssistButtonStyle`, `AssistKeycap`, `AssistNavigationRow`: common controls.
- `SettingsSection`, `SettingToggleRow`, `SettingsDialog`: grouped settings.
- `LibrarySidebar` and `LibraryWelcomeHeader`: library chrome and guidance.

The notch retains its black silhouette to meet the display edge. Its selected
filters, editor tools, and primary actions use the same purple accent family.
Capture geometry, keyboard layouts, and image-editing behavior are unchanged.

All product icons reuse the existing bundled Hugeicons Stroke Rounded assets.
No new icon sources or licenses are introduced; see
`apps/macos/Sources/Assist/Resources/ThirdPartyNotices.md`.
