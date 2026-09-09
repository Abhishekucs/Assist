import { sampleSlot } from "./keyboard";

/** Browser-local preview of the exact PCM assets bundled with Assist. */
export class KeyboardAudio {
  private context?: AudioContext;
  private gain?: GainNode;
  private cache = new Map<string, AudioBuffer[]>();
  private bank?: AudioBuffer[];
  private voices = new Set<AudioBufferSourceNode>();
  private abort?: AbortController;
  private generation = 0;
  private disposed = false;
  private volume = 0.35;

  constructor(
    private createContext = () => new AudioContext({ latencyHint: "interactive" }),
    private fetchSample: typeof fetch = (...args) => fetch(...args)
  ) {}

  async activate(pack: string): Promise<boolean> {
    if (this.disposed) return false;
    const generation = ++this.generation;
    this.abort?.abort();
    const abort = new AbortController();
    this.abort = abort;
    this.bank = undefined;
    this.silence();
    const context = this.context ??= this.createContext();
    if (!this.gain) {
      this.gain = context.createGain();
      this.gain.gain.value = this.volume;
      this.gain.connect(context.destination);
    }
    // Resume inside the user gesture, before waiting for network/decoding.
    const resumed = context.resume();
    try {
      const [, bank] = await Promise.all([resumed, this.load(pack, context, abort.signal)]);
      if (this.disposed || generation !== this.generation) return false;
      this.bank = bank;
      return true;
    } catch (error) {
      if (this.disposed || generation !== this.generation) return false;
      abort.abort();
      throw error;
    }
  }

  private async load(pack: string, context: AudioContext, signal: AbortSignal) {
    const cached = this.cache.get(pack);
    if (cached) return cached;
    const bank = await Promise.all(Array.from({ length: 12 }, async (_, index) => {
      const response = await this.fetchSample(`/keyboard-sounds/${encodeURIComponent(pack)}/${index < 6 ? "down" : "up"}-${index % 6}.wav`, { signal });
      if (!response.ok) throw new Error("This sound could not be loaded. Try it again.");
      return context.decodeAudioData(await response.arrayBuffer());
    }));
    if (!signal.aborted) this.cache.set(pack, bank);
    return bank;
  }

  play(code: string, phase: "down" | "up", variation: number, pan: number) {
    const context = this.context;
    if (!context || context.state !== "running" || !this.bank || !this.gain) return;
    // Keep long, fast sessions bounded; never queue hits behind a loading pack.
    if (this.voices.size >= 32) return;
    const source = context.createBufferSource();
    const panner = context.createStereoPanner();
    source.buffer = this.bank[sampleSlot(code, variation) + (phase === "up" ? 6 : 0)];
    panner.pan.value = pan;
    source.connect(panner).connect(this.gain);
    source.onended = () => {
      this.voices.delete(source);
      source.disconnect();
      panner.disconnect();
    };
    this.voices.add(source);
    source.start();
  }

  setVolume(volume: number) {
    this.volume = Math.max(0, Math.min(1, volume));
    if (this.gain) this.gain.gain.value = this.volume;
  }

  silence() {
    for (const source of this.voices) source.stop();
    this.voices.clear();
  }

  pause() {
    ++this.generation;
    this.abort?.abort();
    this.bank = undefined;
    this.silence();
    return this.context?.suspend();
  }

  dispose() {
    this.disposed = true;
    ++this.generation;
    this.abort?.abort();
    this.silence();
    this.cache.clear();
    return this.context?.close();
  }
}
