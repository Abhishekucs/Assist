# Keyboard sounds

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
entirely local. No Keeby audio or code is used.
