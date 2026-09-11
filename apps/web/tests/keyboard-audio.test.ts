import assert from "node:assert/strict";
import { test } from "node:test";
import { KeyboardAudio } from "../app/fun/KeyboardAudio";
import { keyboardRows, sampleSlot } from "../app/fun/keyboard";

function contextSpy() {
  const sources: { buffer: unknown; onended?: () => void; stop(): void; connect(node: unknown): unknown; disconnect(): void; start(): void }[] = [];
  let resumes = 0;
  let suspends = 0;
  let closes = 0;
  const context = {
    state: "running", destination: {},
    resume() { resumes++; context.state = "running"; return Promise.resolve(); },
    suspend() { suspends++; context.state = "suspended"; return Promise.resolve(); },
    close() { closes++; context.state = "closed"; return Promise.resolve(); },
    createGain() { return { gain: { value: 0 }, connect() {} }; },
    decodeAudioData(data: ArrayBuffer) { return Promise.resolve({ marker: new Uint8Array(data)[0] }); },
    createBufferSource() {
      const source = { buffer: null as unknown, onended: undefined as (() => void) | undefined,
        stop() { source.onended?.(); }, connect(node: unknown) { return node; }, disconnect() {}, start() {} };
      sources.push(source);
      return source;
    },
    createStereoPanner() { return { pan: { value: 0 }, connect() {}, disconnect() {} }; }
  };
  return { context: context as unknown as AudioContext, sources, counts: () => ({ resumes, suspends, closes }) };
}

const sampleResponse = (marker: number) => new Response(Uint8Array.from([marker]));

test("a real gesture can unlock an earlier focus request without reloading samples", async () => {
  const spy = contextSpy();
  const context = spy.context as unknown as { state: string; resume(): Promise<void> };
  context.state = "suspended";
  let pendingResume: (() => void) | undefined;
  context.resume = () => new Promise<void>(resolve => {
    if (!pendingResume) pendingResume = resolve;
    else { context.state = "running"; pendingResume(); resolve(); }
  });
  let requests = 0;
  const audio = new KeyboardAudio(() => spy.context, (() => {
    requests++;
    return Promise.resolve(sampleResponse(1));
  }) as typeof fetch);
  const focused = audio.activate("thock");
  await audio.resumeOnGesture();
  assert.equal(await focused, true);
  assert.equal(requests, 12);
  audio.play("KeyA", "down", 0, 0);
  assert.equal(spy.sources.length, 1);
  await audio.dispose();
  assert.equal(audio.resumeOnGesture(), undefined);
});

test("a late pack load cannot replace the latest selected sound", async () => {
  const spy = contextSpy();
  const pending: (() => void)[] = [];
  const fetcher = ((url: string) => url.includes("/thock/")
    ? new Promise<Response>(resolve => pending.push(() => resolve(sampleResponse(1))))
    : Promise.resolve(sampleResponse(2))) as typeof fetch;
  const audio = new KeyboardAudio(() => spy.context, fetcher);
  const first = audio.activate("thock");
  assert.equal(spy.counts().resumes, 1, "Audio is unlocked before downloads finish");
  assert.equal(await audio.activate("topre"), true);
  pending.forEach(resolve => resolve());
  assert.equal(await first, false);
  audio.play("KeyA", "down", 0, 0);
  assert.deepEqual(spy.sources[0].buffer, { marker: 2 });
  await audio.dispose();
});

test("pausing during loading prevents stale playback and leaving closes audio", async () => {
  const spy = contextSpy();
  const pending: (() => void)[] = [];
  const audio = new KeyboardAudio(() => spy.context, (() => new Promise<Response>(resolve => {
    pending.push(() => resolve(sampleResponse(1)));
  })) as typeof fetch);
  const loading = audio.activate("thock");
  await audio.pause();
  pending.forEach(resolve => resolve());
  assert.equal(await loading, false);
  audio.play("Space", "up", 0, 0);
  assert.equal(spy.sources.length, 0);
  await audio.dispose();
  assert.equal(await audio.activate("thock"), false);
  assert.equal(spy.counts().closes, 1);
});

test("failed downloads can be retried and overlapping voices stay bounded", async () => {
  const spy = contextSpy();
  let fail = true;
  let requests = 0;
  const audio = new KeyboardAudio(() => spy.context, (() => {
    requests++;
    return Promise.resolve(fail ? new Response(null, { status: 404 }) : sampleResponse(1));
  }) as typeof fetch);
  await assert.rejects(audio.activate("thock"));
  fail = false;
  assert.equal(await audio.activate("thock"), true);
  for (let i = 0; i < 100; i++) audio.play("KeyA", "down", 0, 0);
  assert.equal(spy.sources.length, 32);
  audio.silence();
  audio.play("Enter", "up", 0, 0);
  assert.equal(spy.sources.length, 33);
  const before = requests;
  await audio.activate("thock");
  assert.equal(requests, before, "Decoded packs are reused");
  await audio.dispose();
});

test("ordinary keys, space, return and deletion select their press/release slots", () => {
  assert.equal(sampleSlot("Space", 2), 3);
  assert.equal(sampleSlot("Enter", 1), 4);
  assert.equal(sampleSlot("Backspace", 0), 5);
  assert.equal(sampleSlot("Delete", 2), 5);
  assert.deepEqual([0,1,2,3,4].map(i => sampleSlot("KeyA", i)), [0,1,2,0,1]);
  assert.equal(new Set(keyboardRows.flat().map(key => key.code)).size, keyboardRows.flat().length);
  for (const row of keyboardRows) assert.equal(row.reduce((sum, key) => sum + key.units, 0), 15);
});
