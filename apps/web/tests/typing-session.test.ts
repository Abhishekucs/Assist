import assert from "node:assert/strict";
import { test } from "node:test";
import { createTypingSession, makePassage, typingMetrics, typingReducer, type TypingSession } from "../app/fun/typingSession";

function session(): TypingSession {
  return { ...createTypingSession(), words: ["hello", "world", "sound", "type"] };
}

test("the first character starts the clock and correct text earns WPM", () => {
  let state = session();
  assert.deepEqual(typingMetrics(state), { wpm: 0, accuracy: 100, remaining: 30 });
  state = typingReducer(state, { type: "tick", now: 20_000 });
  assert.equal(state.phase, "ready");
  state = typingReducer(state, { type: "input", value: "h", now: 20_000 });
  state = typingReducer(state, { type: "input", value: "hello world ", now: 26_000 });
  assert.deepEqual(typingMetrics(state), { wpm: 24, accuracy: 100, remaining: 24 });
});

test("correcting an error removes its highlight without erasing accuracy history", () => {
  let state = typingReducer(session(), { type: "input", value: "hex", now: 0 });
  assert.equal(state.attempts, 3);
  assert.equal(typingMetrics(state).accuracy, 67);
  state = typingReducer(state, { type: "input", value: "he", now: 500 });
  assert.equal(state.attempts, 3);
  state = typingReducer(state, { type: "input", value: "hello ", now: 1000 });
  assert.equal(state.attempts, 7);
  assert.equal(state.correctAttempts, 6);
  assert.equal(typingMetrics(state).accuracy, 86);
});

test("space advances past misspelled or skipped words without shifting later matches", () => {
  let state = typingReducer(session(), { type: "input", value: "he ", now: 0 });
  state = typingReducer(state, { type: "input", value: "he world ", now: 2000 });
  assert.equal(state.correctAttempts, 8);
  assert.equal(typingMetrics(state).wpm, 48);
  state = typingReducer(state, { type: "input", value: "he world  t", now: 3000 });
  assert.equal(state.correctAttempts, 9);
});

test("pause excludes time spent changing settings and resumes on input", () => {
  let state = typingReducer(session(), { type: "input", value: "h", now: 0 });
  state = typingReducer(state, { type: "pause", now: 2000 });
  assert.equal(state.phase, "paused");
  state = typingReducer(state, { type: "tick", now: 100_000 });
  assert.equal(state.elapsedMs, 2000);
  state = typingReducer(state, { type: "input", value: "he", now: 110_000 });
  state = typingReducer(state, { type: "tick", now: 111_000 });
  assert.equal(state.elapsedMs, 3000);
  assert.equal(state.phase, "running");
});

test("a late tick or input cannot extend the deadline or change a finished result", () => {
  let state = typingReducer(session(), { type: "input", value: "hello", now: 1000 });
  state = typingReducer(state, { type: "input", value: "hello world", now: 31_001 });
  assert.equal(state.phase, "complete");
  assert.equal(state.value, "hello");
  assert.equal(state.elapsedMs, 30_000);
  assert.equal(typingMetrics(state).remaining, 0);
  assert.deepEqual(typingReducer(state, { type: "pause", now: 90_000 }), state);
  assert.deepEqual(typingReducer(state, { type: "input", value: "", now: 95_000 }), state);
});

test("finishing the passage stops early and restart resets every score with new words", () => {
  let state = typingReducer(session(), { type: "input", value: "hello world sound ", now: 0 });
  state = typingReducer(state, { type: "input", value: "hello world sound type", now: 6000 });
  assert.equal(state.phase, "complete");
  assert.deepEqual(typingMetrics(state), { wpm: 44, accuracy: 100, remaining: 24 });
  state = typingReducer(state, { type: "restart", duration: 15, seed: 1 });
  assert.equal(state.phase, "ready");
  assert.equal(state.value, "");
  assert.equal(state.attempts, 0);
  assert.deepEqual(typingMetrics(state), { wpm: 0, accuracy: 100, remaining: 15 });
  assert.deepEqual(makePassage(0), makePassage(0));
  assert.notDeepEqual(makePassage(0), makePassage(1));
});
