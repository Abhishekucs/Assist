#!/usr/bin/env python3
"""Build four recorded-sample presets. Requires macOS afconvert, numpy and scipy.

Run from any directory; assets are committed, so normal app builds need neither
Python nor network access. Source revision and licenses are pinned below.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import urllib.request

import numpy as np
from scipy import signal
from scipy.io import wavfile

REVISION = "326252a13e7bef4f1c35d08ef0189b5af6f8ba02"
SOURCE = f"https://raw.githubusercontent.com/hainguyents13/mechvibes/{REVISION}/src/audio/holy-pandas/"
OUTPUT = Path(__file__).resolve().parents[1] / "Sources/Assist/Resources/Sounds"
RATE = 48000
KEYS = ["GENERIC_R1", "GENERIC_R2", "GENERIC_R3", "SPACE", "ENTER", "BACKSPACE"]
PRESETS = {"soft": (0.96, 1800), "thock": (0.78, 4200), "clicky": (1.08, 14000), "typewriter": (1.18, 10000)}


def shape(samples, pack, phase):
    pitch, cutoff = PRESETS[pack]
    x = signal.resample_poly(samples, 100, round(pitch * 100))
    x = signal.sosfilt(signal.butter(2, 90, "highpass", fs=RATE, output="sos"), x)
    x = signal.sosfilt(signal.butter(2, cutoff, fs=RATE, output="sos"), x)
    if pack == "clicky":
        bright = signal.sosfilt(signal.butter(1, 2500, "highpass", fs=RATE, output="sos"), x)
        x = x + bright * 0.8
    if pack == "typewriter":
        # A short resonant metal-body treatment, derived from the recording.
        b, a = signal.iirpeak(2300, 5, fs=RATE)
        x = x + 2.2 * signal.lfilter(b, a, x)
    active = np.flatnonzero(np.abs(x) > max(np.max(np.abs(x)) * 0.012, 0.0001))
    if not len(active):
        raise ValueError("Empty source recording")
    x = x[max(0, active[0] - 24):min(len(x), active[-1] + 145)]
    fade = min(96, len(x) // 4)
    x[:24] *= np.linspace(0, 1, 24)
    x[-fade:] *= np.linspace(1, 0, fade)
    # Match energy across presets without making releases as loud as presses.
    rms = np.sqrt(np.mean(x * x))
    target = 0.085 if phase == "down" else 0.033
    x *= min(target / rms, 0.72 / np.max(np.abs(x)))
    return (np.clip(x, -1, 1) * 32767).astype(np.int16)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {"version": 1, "sampleRate": RATE, "sourceRevision": REVISION, "packs": []}
    with tempfile.TemporaryDirectory(prefix="assist-sound-build-") as directory:
        cache = Path(directory)
        sources = {}
        for phase in ["down", "up"]:
            for key in KEYS:
                name = f"{key}.mp3" if phase == "down" else f"release/{'GENERIC' if key.startswith('GENERIC') else key}.mp3"
                if name in sources:
                    continue
                mp3 = cache / name
                mp3.parent.mkdir(parents=True, exist_ok=True)
                mp3.write_bytes(urllib.request.urlopen(SOURCE + name).read())
                wav = mp3.with_suffix(".wav")
                subprocess.run(["/usr/bin/afconvert", "-f", "WAVE", "-d", "LEI16@48000", "-c", "1", str(mp3), str(wav)], check=True)
                rate, data = wavfile.read(wav)
                assert rate == RATE and data.ndim == 1
                sources[name] = data.astype(np.float64) / 32768
        for pack in PRESETS:
            files = []
            folder = OUTPUT / pack
            folder.mkdir(exist_ok=True)
            for phase in ["down", "up"]:
                for index, key in enumerate(KEYS):
                    name = f"{key}.mp3" if phase == "down" else f"release/{'GENERIC' if key.startswith('GENERIC') else key}.mp3"
                    file = folder / f"{phase}-{index}.wav"
                    wavfile.write(file, RATE, shape(sources[name], pack, phase))
                    files.append({"file": f"{pack}/{file.name}", "sha256": hashlib.sha256(file.read_bytes()).hexdigest()})
            manifest["packs"].append({"id": pack, "samples": files})
        (OUTPUT / "LICENSE.txt").write_bytes(urllib.request.urlopen(SOURCE + "LICENSE").read())
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
