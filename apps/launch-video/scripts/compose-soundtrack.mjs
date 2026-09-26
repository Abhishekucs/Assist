// Composes the launch video's soundtrack: an original 120 BPM track plus
// sound design cued to the picture. Everything is synthesized here except the
// typing and key presses, which use Assist's own "Soft" keyboard pack
// (MIT, see apps/web/public/keyboard-sounds/README.md).
//
// Output: public/audio/soundtrack.wav (48 kHz, 16-bit stereo). Deterministic.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const timeline = JSON.parse(readFileSync(join(root, "src/timeline.json"), "utf8"));

const SR = 48000;
const DURATION = timeline.duration;
const N = Math.ceil(DURATION * SR);
const BEAT = 60 / timeline.bpm;
const BAR = BEAT * 4;
const S16 = BEAT / 4;
const scene = (name) => timeline.scenes[name];

// ---------------------------------------------------------------------------
// Cues. Scene-relative offsets mirror the animation timings in src/scenes.

const CUES = {
  impacts: [
    { at: 4.0, size: 0.55 }, // the notch opens
    { at: scene("brand").start, size: 1 },
    { at: scene("context").start, size: 0.8 },
    { at: scene("modules").start, size: 0.9 },
    { at: scene("capture").start, size: 0.7 },
    { at: timeline.keyPresses[1] + 0.25, size: 0.8, bright: true }, // capture flash
    { at: scene("voice").start, size: 0.9 },
    { at: scene("voice").start + 0.5, size: 0.9 },
    { at: scene("voice").start + 1.0, size: 1 },
    { at: scene("benefits").start, size: 0.9 },
    { at: scene("outro").start, size: 1.25 }
  ],
  whooshes: [
    5.5,
    scene("brand").start + 5.1,
    scene("context").start + 4.35, // cut to the timers clip
    scene("context").start + 7.3,
    scene("modules").start + 1.5,
    scene("capture").start - 0.55,
    scene("voice").start + 1.4,
    scene("benefits").start - 0.55,
    scene("benefits").start + 5.4,
    scene("trusted").start + 2.55
  ],
  risers: [
    [2.4, 4.0, 0.45],
    [scene("brand").start + 4, scene("context").start, 1],
    [scene("context").start + 6, scene("modules").start, 0.8],
    [scene("capture").start - 2, scene("capture").start, 0.9],
    [scene("benefits").start - 2, scene("benefits").start, 0.9],
    [scene("outro").start - 1.5, scene("outro").start, 1]
  ],
  // Module switches in the carousel, then the icon grid popping in.
  ticks: Array.from({ length: 10 }, (_, i) => timeline.moduleCarousel.start + i * timeline.moduleCarousel.step),
  blips: Array.from({ length: 11 }, (_, i) => scene("modules").start + 12 + 0.6 + i * 0.05),
  keyPresses: timeline.keyPresses,
  typing: timeline.typing
};

// Arrangement, in bars (2 s each at 120 BPM).
const bar = (t) => Math.floor(t / BAR + 1e-9);
const FULL = new Set([6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 23, 24, 25, 26, 27, 28]);
const section = {
  kick: (t) => {
    const b = bar(t);
    if (b === 10) return true; // four on the floor under "Make the notch yours."
    if (b === 17) return t < 35.5; // drop out before the dark reveal
    if (b === 22) return false; // "Point. Speak. Done." hits alone
    if (b === 24) return t < 49.5;
    if (b === 28) return t < 58.5;
    return FULL.has(b);
  },
  clap: (t) => FULL.has(bar(t)) && bar(t) !== 23,
  hats: (t) => (bar(t) >= 4 && bar(t) <= 5) || FULL.has(bar(t)) || bar(t) === 17,
  bass: (t) => FULL.has(bar(t)) || bar(t) === 10 || (bar(t) === 17 && t < 35.5),
  pluck: (t) => t >= 6 && t < 59 && !(t >= 44 && t < 45.5),
  snareRoll: (t) => (t >= 10 && t < 12) || (t >= 34 && t < 35.5) || (t >= 48 && t < 49.5)
};

// ---------------------------------------------------------------------------
// DSP helpers.

const midi = (m) => 440 * Math.pow(2, (m - 69) / 12);
let seed = 0x5eed;
const rand = () => {
  seed = (seed * 1664525 + 1013904223) >>> 0;
  return seed / 4294967296;
};
const noise = () => rand() * 2 - 1;

function polyBlep(t, dt) {
  if (t < dt) {
    t /= dt;
    return t + t - t * t - 1;
  }
  if (t > 1 - dt) {
    t = (t - 1) / dt;
    return t * t + t + t + 1;
  }
  return 0;
}

class Biquad {
  constructor() {
    this.x1 = this.x2 = this.y1 = this.y2 = 0;
  }
  set(type, freq, q = 0.707, gainDb = 0) {
    const w = (2 * Math.PI * Math.min(freq, SR * 0.45)) / SR;
    const cos = Math.cos(w);
    const alpha = Math.sin(w) / (2 * q);
    const A = Math.pow(10, gainDb / 40);
    let b0, b1, b2, a0, a1, a2;
    if (type === "lowpass") {
      b0 = (1 - cos) / 2; b1 = 1 - cos; b2 = b0;
      a0 = 1 + alpha; a1 = -2 * cos; a2 = 1 - alpha;
    } else if (type === "highpass") {
      b0 = (1 + cos) / 2; b1 = -(1 + cos); b2 = b0;
      a0 = 1 + alpha; a1 = -2 * cos; a2 = 1 - alpha;
    } else if (type === "bandpass") {
      b0 = alpha; b1 = 0; b2 = -alpha;
      a0 = 1 + alpha; a1 = -2 * cos; a2 = 1 - alpha;
    } else if (type === "highshelf") {
      const s = Math.sqrt(A);
      b0 = A * ((A + 1) + (A - 1) * cos + 2 * s * alpha);
      b1 = -2 * A * ((A - 1) + (A + 1) * cos);
      b2 = A * ((A + 1) + (A - 1) * cos - 2 * s * alpha);
      a0 = (A + 1) - (A - 1) * cos + 2 * s * alpha;
      a1 = 2 * ((A - 1) - (A + 1) * cos);
      a2 = (A + 1) - (A - 1) * cos - 2 * s * alpha;
    }
    this.b0 = b0 / a0; this.b1 = b1 / a0; this.b2 = b2 / a0;
    this.a1 = a1 / a0; this.a2 = a2 / a0;
    return this;
  }
  run(x) {
    const y = this.b0 * x + this.b1 * this.x1 + this.b2 * this.x2 - this.a1 * this.y1 - this.a2 * this.y2;
    this.x2 = this.x1; this.x1 = x;
    this.y2 = this.y1; this.y1 = y;
    return y;
  }
}

const stereo = () => ({ L: new Float32Array(N), R: new Float32Array(N) });
const bus = {
  drums: stereo(),
  bass: stereo(),
  pad: stereo(),
  pluck: stereo(),
  fx: stereo(),
  keys: stereo(),
  reverb: stereo()
};

function put(target, i, l, r) {
  if (i >= 0 && i < N) {
    target.L[i] += l;
    target.R[i] += r;
  }
}
const panGains = (pan) => [Math.cos(((pan + 1) * Math.PI) / 4), Math.sin(((pan + 1) * Math.PI) / 4)];

// ---------------------------------------------------------------------------
// Harmony: Fmaj7 – G6 – Am7 – Cadd9, one chord per bar.

const CHORDS = [
  { root: 41, pad: [53, 57, 60, 64], arp: [65, 69, 72, 76] },
  { root: 43, pad: [55, 59, 62, 64], arp: [67, 71, 74, 76] },
  { root: 45, pad: [57, 60, 64, 67], arp: [69, 72, 76, 79] },
  { root: 36, pad: [55, 60, 62, 64], arp: [67, 72, 74, 76] }
];
const chordAt = (t) => CHORDS[bar(t) % CHORDS.length];

// ---------------------------------------------------------------------------
// Instruments.

function kick(at, gain = 1) {
  const start = Math.round(at * SR);
  const len = Math.round(0.5 * SR);
  let phase = 0;
  for (let n = 0; n < len; n++) {
    const t = n / SR;
    const freq = 52 + 120 * Math.exp(-t * 38);
    phase += (2 * Math.PI * freq) / SR;
    const amp = Math.exp(-t * 7.5) * Math.min(1, n / 24);
    let s = Math.tanh(Math.sin(phase) * 1.6) * amp;
    if (n < 240) s += noise() * 0.18 * (1 - n / 240);
    put(bus.drums, start + n, s * gain, s * gain);
  }
}

function clap(at, gain = 1) {
  const start = Math.round(at * SR);
  const len = Math.round(0.3 * SR);
  const bp = new Biquad().set("bandpass", 1400, 0.9);
  const hp = new Biquad().set("highpass", 600);
  for (let n = 0; n < len; n++) {
    const t = n / SR;
    const bursts = [0, 0.011, 0.023].reduce((sum, offset) => sum + (t >= offset ? Math.exp(-(t - offset) * 180) : 0), 0);
    const env = bursts * 0.55 + Math.exp(-t * 16) * 0.5;
    const s = hp.run(bp.run(noise())) * env * gain;
    put(bus.drums, start + n, s * 0.9, s);
    put(bus.reverb, start + n, s * 0.35, s * 0.35);
  }
}

function hat(at, gain, open = false) {
  const start = Math.round(at * SR);
  const decay = open ? 9 : 55;
  const len = Math.round((open ? 0.35 : 0.08) * SR);
  const hp = new Biquad().set("highpass", 7500, 0.8);
  const pan = open ? 0.25 : -0.2;
  const [gl, gr] = panGains(pan);
  for (let n = 0; n < len; n++) {
    const s = hp.run(noise()) * Math.exp((-n / SR) * decay) * gain;
    put(bus.drums, start + n, s * gl, s * gr);
  }
}

function snare(at, gain) {
  const start = Math.round(at * SR);
  const len = Math.round(0.14 * SR);
  const bp = new Biquad().set("bandpass", 2200, 0.7);
  let phase = 0;
  for (let n = 0; n < len; n++) {
    const t = n / SR;
    phase += (2 * Math.PI * 190) / SR;
    const s = (bp.run(noise()) * 0.9 + Math.sin(phase) * 0.35) * Math.exp(-t * 30) * gain;
    put(bus.drums, start + n, s, s);
    put(bus.reverb, start + n, s * 0.2, s * 0.2);
  }
}

function bassNote(at, length, note, gain) {
  const start = Math.round(at * SR);
  const len = Math.round((length + 0.05) * SR);
  const freq = midi(note);
  const lp = new Biquad().set("lowpass", 520, 1.1);
  let phase = 0;
  for (let n = 0; n < len; n++) {
    const t = n / SR;
    phase += freq / SR;
    const p = phase % 1;
    const saw = 2 * p - 1 - polyBlep(p, freq / SR);
    const body = Math.sin(2 * Math.PI * phase);
    const env = Math.min(1, n / 60) * (t < length ? Math.exp(-t * 3) * 0.6 + 0.4 : Math.max(0, 1 - (t - length) / 0.05));
    const s = Math.tanh((lp.run(saw) * 0.7 + body * 0.9) * 1.4) * env * gain;
    put(bus.bass, start + n, s, s);
  }
}

function padChord(at, length, notes, gain) {
  const start = Math.round(at * SR);
  const len = Math.round((length + 1.2) * SR);
  const voices = [];
  for (const note of notes) {
    for (let v = 0; v < 5; v++) {
      const detune = (v - 2) * 0.09;
      voices.push({ freq: midi(note + detune), phase: rand(), pan: (v % 2 ? -1 : 1) * (0.25 + v * 0.12) });
    }
  }
  const scale = gain / voices.length;
  for (let n = 0; n < len; n++) {
    const t = n / SR;
    const env = Math.min(1, t / 0.5) * (t < length ? 1 : Math.exp(-(t - length) * 3.2));
    let l = 0;
    let r = 0;
    for (const voice of voices) {
      const dt = voice.freq / SR;
      voice.phase += dt;
      if (voice.phase >= 1) voice.phase -= 1;
      const s = 2 * voice.phase - 1 - polyBlep(voice.phase, dt);
      l += s * (1 - voice.pan) * 0.5;
      r += s * (1 + voice.pan) * 0.5;
    }
    put(bus.pad, start + n, l * env * scale, r * env * scale);
  }
}

function pluckNote(at, note, gain, pan) {
  const start = Math.round(at * SR);
  const len = Math.round(0.42 * SR);
  const freq = midi(note);
  const dt = freq / SR;
  const lp = new Biquad();
  const [gl, gr] = panGains(pan);
  let phase = rand();
  for (let n = 0; n < len; n++) {
    const t = n / SR;
    if (n % 16 === 0) lp.set("lowpass", 700 + 5200 * Math.exp(-t * 22), 0.9);
    phase += dt;
    if (phase >= 1) phase -= 1;
    const saw = 2 * phase - 1 - polyBlep(phase, dt);
    const square = (phase < 0.5 ? 1 : -1) + polyBlep(phase, dt) - polyBlep((phase + 0.5) % 1, dt);
    const s = lp.run(saw * 0.6 + square * 0.4) * Math.exp(-t * 9) * Math.min(1, n / 40) * gain;
    put(bus.pluck, start + n, s * gl, s * gr);
  }
}

function impact(at, size, bright = false) {
  const start = Math.round(at * SR);
  const len = Math.round(2.4 * SR);
  const lp = new Biquad().set("lowpass", bright ? 5000 : 1800, 0.7);
  let phase = 0;
  for (let n = 0; n < len; n++) {
    const t = n / SR;
    phase += (2 * Math.PI * (34 + 70 * Math.exp(-t * 9))) / SR;
    const boom = Math.sin(phase) * Math.exp(-t * 2.1) * Math.min(1, n / 30);
    const hit = lp.run(noise()) * Math.exp(-t * (bright ? 7 : 11));
    const s = (boom * 0.95 + hit * 0.55) * size;
    put(bus.fx, start + n, s, s);
    put(bus.reverb, start + n, hit * size * 0.5, hit * size * 0.5);
  }
}

function whoosh(at, gain = 0.5) {
  const length = 0.7;
  const start = Math.round((at - 0.2) * SR);
  const len = Math.round(length * SR);
  const bp = new Biquad();
  for (let n = 0; n < len; n++) {
    const x = n / len;
    if (n % 32 === 0) bp.set("bandpass", 400 * Math.pow(12, Math.sin(Math.PI * x)), 1.4);
    const env = Math.pow(Math.sin(Math.PI * Math.pow(x, 0.7)), 2);
    const s = bp.run(noise()) * env * gain;
    const pan = -0.7 + 1.4 * x;
    const [gl, gr] = panGains(pan);
    put(bus.fx, start + n, s * gl, s * gr);
    put(bus.reverb, start + n, s * 0.3, s * 0.3);
  }
}

function riser(from, to, gain) {
  const start = Math.round(from * SR);
  const len = Math.round((to - from) * SR);
  const bp = new Biquad();
  let phase = 0;
  for (let n = 0; n < len; n++) {
    const x = n / len;
    if (n % 32 === 0) bp.set("bandpass", 300 * Math.pow(30, x), 2.2);
    phase += (2 * Math.PI * (180 * Math.pow(4, x))) / SR;
    const env = Math.pow(x, 2.2) * Math.min(1, (len - n) / 480);
    const s = (bp.run(noise()) * 0.9 + Math.sin(phase) * 0.12) * env * gain;
    const wobble = Math.sin(x * 18) * 0.3;
    const [gl, gr] = panGains(wobble);
    put(bus.fx, start + n, s * gl, s * gr);
    put(bus.reverb, start + n, s * 0.4, s * 0.4);
  }
}

function tick(at, gain, pitch = 1) {
  const start = Math.round(at * SR);
  const len = Math.round(0.08 * SR);
  for (let n = 0; n < len; n++) {
    const t = n / SR;
    const s =
      (Math.sin(2 * Math.PI * 2100 * pitch * t) * Math.exp(-t * 90) * 0.6 +
        Math.sin(2 * Math.PI * 1050 * pitch * t) * Math.exp(-t * 60) * 0.5) *
      gain;
    put(bus.fx, start + n, s, s);
    put(bus.reverb, start + n, s * 0.25, s * 0.25);
  }
}

function blip(at, note, gain) {
  const start = Math.round(at * SR);
  const len = Math.round(0.35 * SR);
  const freq = midi(note);
  for (let n = 0; n < len; n++) {
    const t = n / SR;
    const s = (Math.sin(2 * Math.PI * freq * t) + 0.25 * Math.sin(4 * Math.PI * freq * t)) * Math.exp(-t * 14) * Math.min(1, n / 48) * gain;
    put(bus.fx, start + n, s, s);
    put(bus.reverb, start + n, s * 0.5, s * 0.5);
  }
}

// ---------------------------------------------------------------------------
// Keyboard samples.

function readWav(path) {
  const data = readFileSync(path);
  let offset = 12;
  let format;
  while (offset < data.length) {
    const id = data.toString("ascii", offset, offset + 4);
    const size = data.readUInt32LE(offset + 4);
    if (id === "fmt ") format = { channels: data.readUInt16LE(offset + 10), bits: data.readUInt16LE(offset + 22) };
    if (id === "data") {
      if (format.bits !== 16) throw new Error(`${path}: expected 16-bit PCM`);
      const frames = size / 2 / format.channels;
      const out = new Float32Array(frames);
      for (let i = 0; i < frames; i++) out[i] = data.readInt16LE(offset + 8 + i * 2 * format.channels) / 32768;
      return out;
    }
    offset += 8 + size + (size % 2);
  }
  throw new Error(`${path}: no data chunk`);
}

const keyDir = join(root, "public/keyboard-sounds/soft");
const keySample = (name) => readWav(join(keyDir, `${name}.wav`));
const KEYS = {
  down: [0, 1, 2].map((i) => keySample(`down-${i}`)),
  up: [0, 1, 2].map((i) => keySample(`up-${i}`)),
  spaceDown: keySample("down-3"),
  spaceUp: keySample("up-3")
};

function playSample(sample, at, gain, pan) {
  const start = Math.round(at * SR);
  const [gl, gr] = panGains(pan);
  for (let n = 0; n < sample.length; n++) put(bus.keys, start + n, sample[n] * gain * gl, sample[n] * gain * gr);
}

// ---------------------------------------------------------------------------
// Arrangement.

const sidechain = new Float32Array(N).fill(1);
function duck(at, depth = 0.62, recover = 0.24) {
  const start = Math.round(at * SR);
  const len = Math.round(recover * SR);
  for (let n = 0; n < len; n++) {
    const i = start + n;
    if (i >= N) break;
    const g = 1 - depth * Math.pow(1 - n / len, 2);
    sidechain[i] = Math.min(sidechain[i], g);
  }
}

// Pad: one chord per bar; outro holds a final Cadd9.
for (let b = 0; b * BAR < scene("outro").start; b++) {
  const at = b * BAR;
  const gain = at < 6 ? 0.7 : 0.62;
  padChord(at, BAR, chordAt(at).pad, gain);
}
padChord(scene("outro").start, 5.2, [48, 55, 60, 62, 64, 67], 0.9);
bassNote(scene("outro").start, 3.5, 36, 0.8);

for (let step = 0; step * S16 < DURATION; step++) {
  const t = step * S16;
  const inBeat = step % 4;
  const chord = chordAt(t);

  if (inBeat === 0 && section.kick(t)) {
    const soft = bar(t) === 10 ? 0.85 : 1;
    kick(t, soft);
    duck(t);
  }
  if (inBeat === 0 && step % 8 === 4 && section.clap(t)) clap(t, 0.55);
  if (section.hats(t)) {
    if (inBeat === 2 && FULL.has(bar(t))) hat(t, 0.16, true);
    else hat(t, inBeat === 0 ? 0.07 : 0.1 + (inBeat === 2 ? 0.02 : 0));
  }
  if (section.bass(t) && inBeat === 2) bassNote(t, S16 * 1.6, chord.root, 0.6);
  if (section.pluck(t)) {
    const order = [0, 2, 1, 3, 2, 0, 3, 1];
    const note = chord.arp[order[step % order.length]] + (step % 16 >= 12 ? 12 : 0);
    const level = (t < 12 ? 0.11 : 0.15) * (inBeat === 0 ? 1.15 : 0.9);
    pluckNote(t, note, level, step % 2 ? 0.35 : -0.35);
  }
  if (section.snareRoll(t)) {
    const sectionEnd = [12, 35.5, 49.5].find((end) => t < end);
    const window = sectionEnd === 12 ? 2 : 1.5;
    const progress = 1 - (sectionEnd - t) / window;
    const density = progress < 0.5 ? 2 : 1;
    if (step % density === 0) snare(t, 0.08 + 0.25 * progress * progress);
  }
}

// A final descending arpeggio over the outro chord.
[79, 76, 74, 72, 67, 64].forEach((note, i) => pluckNote(scene("outro").start + 0.5 + i * BEAT * 0.75, note, 0.12 * (1 - i * 0.1), i % 2 ? 0.4 : -0.4));

for (const { at, size, bright } of CUES.impacts) impact(at, size * 0.85, bright);
for (const at of CUES.whooshes) whoosh(at, 0.42);
for (const [from, to, gain] of CUES.risers) riser(from, to, gain * 0.5);
CUES.ticks.forEach((at) => tick(at, 0.16));
const PENTATONIC = [72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96];
CUES.blips.forEach((at, i) => blip(at, PENTATONIC[i], 0.07));

for (const { start, text, cps } of CUES.typing) {
  [...text].forEach((char, i) => {
    const at = start + i / cps + (rand() - 0.5) * 0.012;
    const pan = ((i / Math.max(1, text.length - 1)) * 2 - 1) * 0.35;
    const variant = i % 3;
    playSample(char === " " ? KEYS.spaceDown : KEYS.down[variant], at, 0.9, pan);
    playSample(char === " " ? KEYS.spaceUp : KEYS.up[variant], at + 0.075, 0.55, pan);
  });
}
timeline.keyPresses.forEach((at, i) => playSample(KEYS.down[i % 3], at, 1.3, i ? 0.2 : -0.2));

// ---------------------------------------------------------------------------
// Bus processing.

function filterBus(target, type, cutoffAt, q = 0.707) {
  const fl = new Biquad();
  const fr = new Biquad();
  for (let i = 0; i < N; i++) {
    if (i % 64 === 0) {
      const f = cutoffAt(i / SR);
      fl.set(type, f, q);
      fr.set(type, f, q);
    }
    target.L[i] = fl.run(target.L[i]);
    target.R[i] = fr.run(target.R[i]);
  }
}

// Pad opens up as the video builds; darker under the capture section.
filterBus(bus.pad, "lowpass", (t) => {
  if (t < 6) return 650 + 500 * (t / 6);
  if (t < 12) return 1300 + 900 * ((t - 6) / 6);
  if (t >= 36 && t < 44) return 1500;
  if (t >= 59) return 2600;
  return 2400;
});
filterBus(bus.bass, "lowpass", (t) => (t >= 36 && t < 44 ? 600 : 900));

// Ping-pong delay on the plucks (dotted eighth).
{
  const delay = Math.round(BEAT * 0.75 * SR);
  for (let i = delay; i < N; i++) {
    bus.pluck.L[i] += bus.pluck.R[i - delay] * 0.38;
    bus.pluck.R[i] += bus.pluck.L[i - delay] * 0.38;
  }
}

for (let i = 0; i < N; i++) {
  bus.pad.L[i] *= sidechain[i];
  bus.pad.R[i] *= sidechain[i];
  bus.bass.L[i] *= sidechain[i];
  bus.bass.R[i] *= sidechain[i];
  bus.reverb.L[i] += (bus.pad.L[i] * 0.35 + bus.pluck.L[i] * 0.3) * 1;
  bus.reverb.R[i] += (bus.pad.R[i] * 0.35 + bus.pluck.R[i] * 0.3) * 1;
}

// Freeverb.
function freeverb(input, output, { room = 0.86, damp = 0.35, wet = 0.32, spread = 23 }) {
  const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
  const allpasses = [556, 441, 341, 225];
  const scaleTime = SR / 44100;
  const channel = (src, dst, offset) => {
    const combState = combs.map((len) => ({ buf: new Float32Array(Math.round((len + offset) * scaleTime)), i: 0, store: 0 }));
    const apState = allpasses.map((len) => ({ buf: new Float32Array(Math.round((len + offset) * scaleTime)), i: 0 }));
    for (let n = 0; n < N; n++) {
      const x = src[n] * 0.015;
      let out = 0;
      for (const c of combState) {
        const y = c.buf[c.i];
        c.store = y * (1 - damp) + c.store * damp;
        c.buf[c.i] = x + c.store * room;
        c.i = (c.i + 1) % c.buf.length;
        out += y;
      }
      for (const a of apState) {
        const y = a.buf[a.i];
        a.buf[a.i] = out + y * 0.5;
        a.i = (a.i + 1) % a.buf.length;
        out = y - out;
      }
      dst[n] += out * wet * 3;
    }
  };
  channel(input.L, output.L, 0);
  channel(input.R, output.R, spread);
}

const master = stereo();
freeverb(bus.reverb, master, {});

const LEVELS = { drums: 0.72, bass: 0.7, pad: 1.05, pluck: 1.15, fx: 0.8, keys: 0.95 };
for (const [name, level] of Object.entries(LEVELS)) {
  for (let i = 0; i < N; i++) {
    master.L[i] += bus[name].L[i] * level;
    master.R[i] += bus[name].R[i] * level;
  }
}

// Gentle air, glue, and a soft limiter; fade the tail.
{
  const shelfL = new Biquad().set("highshelf", 9000, 0.7, 2);
  const shelfR = new Biquad().set("highshelf", 9000, 0.7, 2);
  const lowL = new Biquad().set("highpass", 36);
  const lowR = new Biquad().set("highpass", 36);
  const topL = new Biquad().set("lowpass", 16500);
  const topR = new Biquad().set("lowpass", 16500);
  let peak = 0;
  for (let i = 0; i < N; i++) {
    master.L[i] = Math.tanh(topL.run(lowL.run(shelfL.run(master.L[i]))) * 1.1);
    master.R[i] = Math.tanh(topR.run(lowR.run(shelfR.run(master.R[i]))) * 1.1);
    peak = Math.max(peak, Math.abs(master.L[i]), Math.abs(master.R[i]));
  }
  const fadeStart = (DURATION - 2.5) * SR;
  const norm = 0.89 / peak;
  for (let i = 0; i < N; i++) {
    const fade = i > fadeStart ? Math.max(0, 1 - (i - fadeStart) / (2.5 * SR)) : 1;
    master.L[i] *= norm * fade * fade;
    master.R[i] *= norm * fade * fade;
  }
}

// 16-bit stereo WAV.
const pcm = Buffer.alloc(44 + N * 4);
pcm.write("RIFF", 0);
pcm.writeUInt32LE(36 + N * 4, 4);
pcm.write("WAVE", 8);
pcm.write("fmt ", 12);
pcm.writeUInt32LE(16, 16);
pcm.writeUInt16LE(1, 20);
pcm.writeUInt16LE(2, 22);
pcm.writeUInt32LE(SR, 24);
pcm.writeUInt32LE(SR * 4, 28);
pcm.writeUInt16LE(4, 32);
pcm.writeUInt16LE(16, 34);
pcm.write("data", 36);
pcm.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) {
  pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, master.L[i])) * 32767), 44 + i * 4);
  pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, master.R[i])) * 32767), 46 + i * 4);
}
const out = join(root, "public/audio/soundtrack.wav");
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, pcm);
console.log(`Wrote ${out} (${DURATION}s).`);
