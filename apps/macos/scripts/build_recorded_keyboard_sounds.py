#!/usr/bin/env python3
"""Build the licensed recorded-switch catalog; no network is needed at runtime.

Requires macOS afconvert, NumPy and SciPy. Run separately from the four Assist
processed presets in build_keyboard_sounds.py; each catalog has its own manifest.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import urllib.request

import numpy as np
from scipy.io import wavfile

REVISION = "ba103f3b0afa9dab80447aa2e7e2ed80b6bd80e4"
SOURCE = f"https://raw.githubusercontent.com/tplai/kbsim/{REVISION}/"
OUTPUT = Path(__file__).resolve().parents[1] / "Sources/Assist/Resources/Sounds"
RATE = 48000
PACKS = {
    "alpaca": "alpaca", "ink-black": "blackink", "ink-red": "redink",
    "turquoise-tealios": "turquoise", "cream": "cream", "holy-panda": "holypanda",
    "box-navy": "boxnavy", "buckling-spring": "buckling", "topre": "topre",
    "alps-blue": "bluealps",
}
KEYS = ["GENERIC_R1", "GENERIC_R2", "GENERIC_R3", "SPACE", "ENTER", "BACKSPACE"]


def normalize(data, phase):
    x = data.astype(np.float64) / 32768
    active = np.flatnonzero(np.abs(x) > max(np.max(np.abs(x)) * 0.012, 0.0001))
    if not len(active):
        raise ValueError("Empty source recording")
    x = x[max(0, active[0] - 24):min(len(x), active[-1] + 145)]
    if len(x) > RATE:
        raise ValueError("Recording exceeds the renderer's one-second sample limit")
    fade = min(96, len(x) // 4)
    x[:24] *= np.linspace(0, 1, 24)
    x[-fade:] *= np.linspace(1, 0, fade)
    target = 0.085 if phase == "down" else 0.033
    x *= min(target / np.sqrt(np.mean(x * x)), 0.72 / np.max(np.abs(x)))
    return (np.clip(x, -1, 1) * 32767).astype(np.int16)


def main():
    manifest = {"version": 1, "sampleRate": RATE, "sourceRevision": REVISION,
                "sourceRepository": "https://github.com/tplai/kbsim", "packs": []}
    with tempfile.TemporaryDirectory(prefix="assist-recorded-switches-") as directory:
        cache = Path(directory)
        for pack, source_folder in PACKS.items():
            folder = OUTPUT / pack
            folder.mkdir(parents=True, exist_ok=True)
            samples = []
            decoded = {}
            for phase in ["down", "up"]:
                for index, key in enumerate(KEYS):
                    source_key = "GENERIC" if phase == "up" and key.startswith("GENERIC") else key
                    source_path = f"src/assets/audio/{source_folder}/{'press' if phase == 'down' else 'release'}/{source_key}.mp3"
                    if source_path not in decoded:
                        original = urllib.request.urlopen(SOURCE + source_path).read()
                        mp3 = cache / f"{pack}-{phase}-{source_key}.mp3"
                        mp3.write_bytes(original)
                        wav = mp3.with_suffix(".wav")
                        subprocess.run(["/usr/bin/afconvert", "-f", "WAVE", "-d", "LEI16@48000", "-c", "1", str(mp3), str(wav)], check=True)
                        rate, data = wavfile.read(wav)
                        assert rate == RATE and data.ndim == 1
                        decoded[source_path] = (normalize(data, phase), hashlib.sha256(original).hexdigest())
                    output = folder / f"{phase}-{index}.wav"
                    data, source_hash = decoded[source_path]
                    wavfile.write(output, RATE, data)
                    samples.append({"file": f"{pack}/{output.name}", "source": source_path,
                                    "sourceSha256": source_hash, "sha256": hashlib.sha256(output.read_bytes()).hexdigest()})
            manifest["packs"].append({"id": pack, "samples": samples})
            print(f"Built {pack}", flush=True)
    (OUTPUT / "KBSIM-LICENSE.txt").write_bytes(urllib.request.urlopen(SOURCE + "LICENSE.md").read())
    (OUTPUT / "recorded-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
