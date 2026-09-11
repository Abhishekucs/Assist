# Keyboard sounds

The catalog contains 14 packs: four Assist sound designs and ten recorded
switches. All 168 WAV files are bundled for offline playback.

## Assist sound designs

Four sample-based sound designs: Soft, Thock, Clicky and Typewriter. These are
processed presets, not recordings of four different keyboards. Typewriter is
a vintage-inspired treatment, not a recording of a physical typewriter.

Original press and release recordings: Thomas Lai's
[kbsim](https://github.com/tplai/kbsim), distributed by
[Mechvibes](https://github.com/hainguyents13/mechvibes/tree/326252a13e7bef4f1c35d08ef0189b5af6f8ba02/src/audio/holy-pandas)
under the accompanying MIT license (Copyright Thomas Lai).

The build script pins that Mechvibes revision and applies pitch, filtering,
resonance, silence trimming, edge fades and level matching. Three ordinary-key
press variations and distinct Space, Return and Backspace recordings are used.
The generic release recording is shared across the three ordinary-key variants.
All outputs are mono 48 kHz, 16-bit PCM WAV. The manifest records output hashes.

Regenerate with `python3 scripts/build_keyboard_sounds.py` on macOS with NumPy
and SciPy installed. Normal app builds use the committed files; playback is
entirely local.

## Recorded switches

Alpaca, Ink Black, Ink Red, Turquoise Tealios, Cream, Holy Panda, Box Navy,
Buckling Spring, Topre, and SKCM Blue come directly from Thomas Lai's MIT-licensed
[kbsim recordings](https://github.com/tplai/kbsim/tree/ba103f3b0afa9dab80447aa2e7e2ed80b6bd80e4/src/assets/audio).
These are recordings of the switch types, not additional transformations of the
Holy Panda recording. They are not claimed to be identical to Keeby's edited samples.

Source revision: `ba103f3b0afa9dab80447aa2e7e2ed80b6bd80e4`.
`KBSIM-LICENSE.txt` contains the upstream license. `recorded-manifest.json` records
the source paths and original/output SHA-256 hashes for every sample.

Regenerate with `python3 scripts/build_recorded_keyboard_sounds.py`. Processing
only converts to mono 48 kHz PCM, trims silence, fades sample edges, and matches
levels. It does not change pitch or apply a switch-mimicking filter. Three
ordinary-key presses, one generic release, and separate Space/Return/Backspace
presses/releases are included for each switch. The generic release fills the
three ordinary-key variation slots explicitly.

No Keeby audio files or web UI code are bundled. See `docs/keyboard-catalog.md`
for the reference catalog, supported coverage, and unverified sources.
