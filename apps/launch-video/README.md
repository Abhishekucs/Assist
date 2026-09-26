# Assist launch video

A 66-second, 1920 × 1080, 60 fps launch video for Assist, built with
[Remotion](https://www.remotion.dev/). The scenes use only real Assist
material from this repository:

- website demo recordings (`apps/web/public/videos/`)
- module renders of the actual notch views (`apps/web/public/modules/`)
- the app icon, the website's "Trusted by" marks, and its copy
- Inter and the Hugeicons Stroke Rounded icons bundled with the macOS app
- the app's "Soft" keyboard pack for the typing sounds

Colors, type, keycaps, and card tints come from `apps/web/app/globals.css`
and `AssistDesignTokens.swift`; see `src/theme.ts`.

## Storyboard

| Time | Scene | Source |
| --- | --- | --- |
| 0:00 | "Your Mac has a notch." The notch opens into the island. | `modules/clipboard.png` |
| 0:06 | Icon and wordmark, then "One notch. Everyday tools." | homepage hero |
| 0:12 | The app in use: clipboard history, then focus timers. | `notch-modules-demo.mp4` |
| 0:20 | "Make the notch yours." Ten modules, one per beat pair, then all eleven. | module renders, `moduleContent.ts` |
| 0:36 | Control + Option, then crop, blur, and frame in the quick editor. | `screenshot-editor.mp4` |
| 0:44 | "Point. Speak. Done." Voice annotation with a local transcript. | `voice-annotation.mp4` |
| 0:50 | Native, local-first, pay once. | hero note, FAQ, pricing |
| 0:56 | "Trusted by people at" | homepage |
| 0:59 | Lockup, headline, Download for Mac, assistapp.dev. | homepage |

Scene timing lives in `src/timeline.json`, which the soundtrack also reads,
so cuts, keystrokes, and hits stay in sync.

## Build

```sh
cd apps/launch-video
npm ci --workspaces=false
npm run prepare-media   # copy assets from apps/web and apps/macos, compose the soundtrack
npm run studio          # preview and scrub in the browser
npm run render          # writes out/assist-launch.mp4
```

`npm run render` uses Remotion's own headless Chromium. If that download is
blocked, point Remotion at a local Chromium headless shell:

```sh
REMOTION_BROWSER_EXECUTABLE=/path/to/headless_shell npm run render
```

`public/`, `src/generated/`, and `out/` are generated and not committed.

## Soundtrack

`scripts/compose-soundtrack.mjs` synthesizes an original 120 BPM track
(pad, bass, plucks, drums) and the sound design (risers, impacts, whooshes,
module ticks) with no samples or downloads, except the typing and key presses,
which use Assist's "Soft" keyboard pack. The output is deterministic.

## Licenses

- Remotion is free for individuals and companies with up to three employees;
  larger companies need a [company license](https://www.remotion.pro/license).
- Hugeicons free icons: MIT, see
  `apps/macos/Sources/Assist/Resources/Icons/README.md`.
- Keyboard sounds: MIT (Thomas Lai, kbsim), see
  `apps/web/public/keyboard-sounds/README.md`.
- Company marks: Simple Icons and SVG Logos (CC0); the marks remain their
  owners' property. See `apps/web/public/brands/README.md`.
- Inter: SIL Open Font License.
